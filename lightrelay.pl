#!/usr/bin/perl

use strict;
use warnings;
use POE qw(Wheel::FollowTail);
use DBI;
use DBD::mysql;

#### Config Options ####
my $port = "/dev/ttyS0";
my $bank = 1; # Bank number which relays on device belong to
my $color = 'green'; # Set initial color to Green
my $logfile = "/var/log/lightrelay.log"; # Where to output color changes to
my $filename = "dbgpipe.log"; # The file for this script to monitor
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
my $PORT;
# Database Options #
my $host = 'localhost';
my $database = 'lightrelay';
my $table = 'history';
my $user = 'lightrelay';
my $password = 'robot';
my $dsn = "dbi:mysql:$database:$host";


##!! Do not change anything below this line !!##
if (!$command || $command !~ /^(?:start|stop|restart|status|help)$/) {
 print("Usage: lightrelay.pl <start|stop|restart|status|help>\n");
 exit; 
}

if ($command eq "help") {
 print "start:\t\t Start the program.\n";
 print "stop:\t\t Stop the program.\n";
 print "restart:\t Restart the program.\n";
 print "status:\t\t Displays the current color.\n";
 print "help:\t\t This list.\n";
 exit;
}

if ($command eq "status") {
 system("/usr/bin/tail -1 $logfile");
 exit;
}

if ($command eq 'stop') {
 system("/bin/kill `cat /tmp/lightrelay.pid`");
 &turn_relays_off();
 exit;
}

if ($command eq 'restart') {
 system("/bin/kill `cat /tmp/lightrelay.pid`");
 system("/usr/local/bin/lightrelay.pl start &");
 exit;
}

if ($command eq 'start') {
 system("/bin/echo $$ > $pid") == 0 || warn("Can't create PID file $pid: $!\n");
 system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $port") == 0 || die "$!\n";
 open($PORT, "+<", "$port") || die("Can't open $port: $!\n");
 select((select($PORT), $|=1)[0]);

POE::Session->create(
 inline_states => {
  _start	=> \&server_start,
  parse_logfile	=> \&parse_logfile,
  got_log_line	=> \&got_log_line,
  turned_color	=> \&turned_color,
  send_signals	=> \&send_signals,
 }
);

sub server_start {
 $_[KERNEL]->yield("parse_logfile");
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
  $kernel->yield("turned_color", $off_red, $on_green, 'green',' Green');
 } elsif ($line =~ /LG.*alarmed/ && $color eq 'red') { # Red -> Left / Green
  $kernel->yield("turned_color", $off_red, $on_green, 'green', 'Left Green');
 } elsif ($line =~ /Amber.*alarmed/ && $color eq 'green') { # Green -> Amber
  $kernel->yield("turned_color", $off_green, $on_amber, 'amber', 'Amber');
 } elsif ($line =~ /Red.*alarmed/ && $color eq 'amber') { # Amber -> Red
  $kernel->yield("turned_color", $off_amber, $on_red, 'red', 'Red');
 }
}


sub turned_color {
 my ($kernel, $heap, $off, $on, $arg2, $state) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2, ARG3];
 $color = $arg2; # Set color to Green, Amber or Red

 $_[KERNEL]->yield("send_signals" => {cmd => $off});
 $_[KERNEL]->delay("send_signals", .1, {cmd => $on});
# $_[KERNEL]->yield("log", $state);
}

sub send_signals {
 my $arg = $_[ARG0];
 my $cmd = $arg->{cmd};
 print $PORT chr(254);
 print $PORT chr($cmd);
 print $PORT chr(1);
}

sub log {
 my $state = $_[0];
 #open(my $LOGFILE, ">>", "$logfile") or warn "can not open logfile $logfile"; # Open our log file for writing
 #print $LOGFILE "$state\n";
 #close($LOGFILE);
 my $connect = DBI->connect($dsn,$user,$password) or warn "Unable to connect to mysql server $DBI::errstr\n";
 my $time = time();
 my $query = $connect->prepare("INSERT INTO history (color, epoch) VALUES ('$state', '$time()')");
 $query->execute();
}

sub turn_relays_off {
 open($PORT, "+<", "$port") || die("Can't open port $port: $!\n");
 print $PORT chr(254);
 print $PORT chr(29);
 close($PORT);
}

POE::Kernel->run();
exit;
}
