#!/usr/bin/perl

use strict;
use warnings;
use POE qw(Wheel::FollowTail);
use DBI;
use DBD::mysql;
use Time::HiRes qw(time);

#### Config Options ####
my $port = "/dev/ttyS0";
my $color = 'green'; # Set initial color to Green
my $logfile = "/var/log/lightrelay.log"; # Where to output color changes to
my $filename = "/var/www/zm/events/stop-light/dbgpipe.log"; # The file for this script to monitor
my $baud = 115200;
my $command = shift;
my ($green, $amber, $red, $lgreen) = time();
my $on_green = 108;
my $off_green = 100;
my $on_amber = 109;
my $off_amber = 101;
my $on_red = 110;
my $off_red = 102;
my $pid = "/tmp/lightrelay.pid";
my $green_start = time();
my ($amber_start, $red_start, $duration);
my $amber_max = 6;
my $amber_min = 3.33;
my $red_max = 120;
# Database Options #
my $host = 'localhost';
my $database = 'lightrelay';
my $table = 'log';
my $user = 'lightrelay';
my $password = 'robot';
my $dsn = "dbi:mysql:$database:$host";


##!! Do not change anything below this line !!##
if (!$command || $command !~ /^(?:start|stop|help)$/) {
 print("Usage: lightrelay.pl <start|stop|help>\n");
 exit; 
}

if ($command eq "help") {
 print "start:\t\t Start the program.\n";
 print "stop:\t\t Stop the program.\n";
 print "help:\t\t This list.\n";
 exit;
}

if ($command eq 'stop') {
 system("/bin/kill `cat /tmp/lightrelay.pid`");
 &turn_relays_off();
 exit;
}

if ($command eq 'start') {
 system("/bin/echo $$ > $pid") == 0 || warn("Can't create PID file $pid: $!\n");
 system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $port") == 0 || die "$!\n";

POE::Session->create(
 inline_states => {
  _start	=> \&start_watchdog,
  start_watchdog => \&start_watchdog,
  log		=> \&log,
  send_signals	=> \&send_signals,
 }
);

sub start_watchdog {
 my $msg;

 if (($color eq 'amber') && ((time - $amber_start) >= $amber_max)) {
  $color = 'green';
  $msg = "Amber has timed out!  Resetting color to green!";
  $_[KERNEL]->yield("log", => {msg => "$msg"});
  $_[KERNEL]->yield("send_signals" => {cmd => $off_amber});
  $_[KERNEL]->delay("send_signals", .2, {cmd => $on_green});
 } elsif (($color eq 'red') && ((time - $red_start) >= $red_max)) {
  $color = 'green';
  $msg = "Red has timed out!  Resetting color to green!";
  $_[KERNEL]->yield("log", => {msg => "$msg"});
  $_[KERNEL]->yield("send_signals" => {cmd => $off_red});
  $_[KERNEL]->delay("send_signals", .2, {cmd => $on_green});
 }

 $_[KERNEL]->yield("start_watchdog");
}

POE::Session->create(
 inline_states => {
  _start	=> \&start_parsing,
  parse_logfile	=> \&parse_logfile,
  got_log_line	=> \&got_log_line,
  turned_color	=> \&turned_color,
  send_signals	=> \&send_signals,
  log		=> \&log,
 }
);

sub start_parsing {
 $_[KERNEL]->yield("parse_logfile");
 my $msg = "Starting server.";
 $_[KERNEL]->yield("log", => {msg => "$msg"});
}

sub parse_logfile {
 $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
  Filename => "$filename",
  InputEvent => "got_log_line",
 );
}

sub got_log_line {
 my ($kernel, $heap, $line) = @_[KERNEL, HEAP, ARG0];

 if ($line =~ /Green.*alarmed/ && $color eq 'red') { # Red -> Green
  $kernel->yield("turned_color", $off_red, $on_green, 'green', 'Green');
  $green_start = time;
  $duration = time - $red_start;
 } elsif ($line =~ /LG.*alarmed/ && $color eq 'red') { # Red -> Left / Green
  $kernel->yield("turned_color", $off_red, $on_green, 'green', 'Left Green');
  $green_start = time;
  $duration = time - $red_start;
 } elsif ($line =~ /Amber.*alarmed/ && $color eq 'green') { # Green -> Amber
  $kernel->yield("turned_color", $off_green, $on_amber, 'amber', 'Amber');
  $amber_start = time;
  $duration = time - $green_start;
 } elsif ($line =~ /Red.*alarmed/ && $color eq 'amber' && ((time - $amber_start) >= $amber_min)) { # Amber -> Red
  $kernel->yield("turned_color", $off_amber, $on_red, 'red', 'Red');
  $red_start = time;
  $duration = time - $amber_start;
 }
}


sub turned_color {
 my ($kernel, $heap, $off, $on, $arg2, $state) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2, ARG3];
 $color = $arg2; # Set color to Green, Amber or Red

 $_[KERNEL]->yield("send_signals" => {cmd => $off});
 $_[KERNEL]->delay("send_signals", .2, {cmd => $on});
 $_[KERNEL]->yield("log", => {msg => $state});
}

sub send_signals {
 open(my $PORT, "+<", "$port") || die("Can't open $port: $!\n");
 select((select($PORT), $|=1)[0]);
 my $arg = $_[ARG0];
 my $cmd = $arg->{cmd};
 print $PORT chr(254);
 print $PORT chr($cmd);
 print $PORT chr(1);
 close($PORT);
}

sub log {
 my $arg = $_[ARG0];
 my $msg = $arg->{msg};
 my $time = time();

 my $connect = DBI->connect($dsn,$user,$password) or warn "Unable to connect to mysql server $DBI::errstr\n";
 my $query = $connect->prepare("INSERT INTO log (epoch, message) VALUES ('$time()', '$msg')");
 $query->execute();
}

sub turn_relays_off {
 open(my $PORT, "+<", "$port") || die("Can't open port $port: $!\n");
 select((select($PORT), $|=1)[0]);
 print $PORT chr(254);
 print $PORT chr(29);
 close($PORT);
}

POE::Kernel->run();
exit;
}
