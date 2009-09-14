#!/usr/bin/perl

use strict;
use warnings;
use POE qw(Wheel::FollowTail);
use Time::HiRes;

#### Config Options ####
my $bank = 1; # Bank number which relays on device belong to
my $baud = 115200;
my $color = 'green'; # Set initial color to Green
my $detect = 'off';
my $distance = 8.3; # Distance in feet between pucks
my $filename = "dbgpipe.log"; # The file for this script to monitor
my $limit = 45; # Voltage limit while polling for traffic
my $logfile = "/var/log/lightrelay.log"; # Where to output color changes to
my $polltime = .032;
my $port = "/dev/ttyUSB0";
my $sleeptime = .1;
my ($time1, $time2);
my $voltage = 255;
my $on_green = 108;
my $off_green = 100;
my $on_amber = 109;
my $off_amber = 101;
my $on_red = 110;
my $off_red = 102;


##!! Do not change anything below this line !!##
system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $port") == 0 || die($!);
open(my $PORT, "+<", "$port") || die($!);

POE::Session->create(
 inline_states => {
  _start => \&server_start,
  got_log_line => \&got_log_line,
  do_stuff => \&do_stuff,
  detect_traffic => \&detect_traffic,
  switch_relay => \&switch_relay,
  poll => \&switch_relay,
  trigger_zm => \&trigger_zm,
  calculate_speed => \&calculate_speed,
 }
);

POE::Kernel->run();
exit;

sub server_start {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
  Filename => "$filename",
  InputEvent => "got_log_line",
 );
 print "Server started\n";
}
 
sub got_log_line {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 print "$_[ARG0]\n";
 if ($_[ARG0] =~ /Green.*alarmed/ && $color eq 'red') # Color is red; green alarms...
 {
  $kernel->yield("do_stuff", $off_red, $on_green, 'green', 'Green');
 }
 elsif ($_[ARG0] =~ /LG.*alarmed/ && $color eq 'red') # Color is red; left green alarms...
 {
  $kernel->yield("do_stuff", $off_red, $on_green, 'green', 'Left Green');
 }
 elsif ($_[ARG0] =~ /Amber.*alarmed/ && $color eq 'green') # Color is green; amber alarms...
 {
  $kernel->yield("do_stuff", $off_green, $on_amber, 'amber', 'Amber');
 }
 elsif ($_[ARG0] =~ /Red.*alarmed/ && $color eq 'amber') # Color is amber; red alarms...
 {
  $kernel->yield("do_stuff", $off_amber, $on_red, 'red', 'Red');
 }
}

sub do_stuff {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 $color = $_[2]; # Set color

 $kernel->yield("switch_relay", ($_[0], $_[1]));
 #$kernel->yield("detect_traffic");
 #log($_[3]);
}

sub switch_relay {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 select((select($PORT), $|=1)[0]);
 print $PORT chr(254); # Enter Command Mode
 print $PORT chr($_[0]); # Deactivate Previous Relay
 print $PORT chr($bank); # In Bank 1
 select(undef,undef,undef,1); # Sleep for .1sec
 print $PORT chr(254); # Enter Command Mode
 print $PORT chr($_[1]); # Activate Current Relay
 print $PORT chr($bank); # In Bank 1
}

sub detect_traffic {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
  while ($voltage > $limit) {
   $kernel->yield("poll",0);
  }
  $time1 = time;
  $voltage = 255;

  while ($voltage > $limit) {
   $kernel->yield("poll",1);
  }
  $time2 = time;

  kernel->yield("trigger_zm");
  kernel->yield("calculate_speed");
}

sub poll {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 select((select($PORT), $|=1)[0]);
 my $cmd = 150 + $_[0];
 print $PORT chr(254);
 print $PORT chr($cmd);
 $voltage = ord(getc($PORT));
}

sub calculate_speed {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 my $time = $time2 - $time1;
 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
}


sub trigger_zm {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
}

sub log {
 my $state = $_[0];
 open(my $LOGFILE, ">>", "$logfile") or warn($!);
 print $LOGFILE "$state\n";
 close($LOGFILE);
}

sub send_cmd {
 # Need to take into account number of commands sent.
 # I.e. 254, 150, 1 or 254, 27
 select((select($PORT), $|=1)[0]);
 print $PORT chr(254);
 print $port
}
