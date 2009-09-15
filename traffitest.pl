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
#my $filename = "/var/www/zm/events/stop-light/dbgpipe.log"; # The file for this script to monitor
my $filename = "dbgpipe.log";
my $limit = 45; # Voltage limit while polling for traffic
my $logfile = "/var/log/lightrelay.log"; # Where to output color changes to
my $polltime = .032;
my $port = "/dev/ttyS0";
my $sleeptime = .1;
my ($time1, $time2);
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
  _start => sub {
   $_[HEAP]{tailor} = POE::Wheel::FollowTail->new(
    Filename => "$filename",
    InputEvent => "got_log_line",
   );
  },
  got_log_line => \&got_log_line,
  do_stuff => \&do_stuff,
  detect_traffic => \&detect_traffic,
  send_cmd => \&send_cmd,
  trigger_zm => \&trigger_zm,
  calculate_speed => \&calculate_speed,
 }
);

POE::Kernel->run();
exit;

sub got_log_line {
 my ($kernel, $heap, $line) = @_[KERNEL, HEAP, ARG0];

 if ($line =~ /Green.*alarmed/ && $color eq 'red') # Color is red; green alarms...
 {
  $kernel->yield("do_stuff", $off_red, $on_green, 'green', 'Green');
 }
 elsif ($line =~ /LG.*alarmed/ && $color eq 'red') # Color is red; left green alarms...
 {
  $kernel->yield("do_stuff", $off_red, $on_green, 'green', 'Left Green');
 }
 elsif ($line =~ /Amber.*alarmed/ && $color eq 'green') # Color is green; amber alarms...
 {
  $kernel->yield("do_stuff", $off_green, $on_amber, 'amber', 'Amber');
 }
 elsif ($line =~ /Red.*alarmed/ && $color eq 'amber') # Color is amber; red alarms...
 {
  $kernel->yield("do_stuff", $off_amber, $on_red, 'red', 'Red');
 }
}

sub do_stuff {
 my ($kernel, $heap, $off, $on, $arg2, $state) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2, ARG3];
 $color = $arg2;
 print "Color is now $color\n";

 $kernel->yield("send_cmd", $off);
 $kernel->yield("send_cmd", $on);
 $kernel->yield("detect_traffic");
 #log($_[3]);
}

sub detect_traffic {
 my ($kernel, $heap) = @_[KERNEL, HEAP];

 if ($heap->{voltage} > $limit) {
  $kernel->yield("send_cmd", 150);
  $kernel->yield("detect_traffic");
  print "Channel 1 has voltage $heap->{voltage}\n";
  return;
 }
 $time1 = time;
 $heap->{voltage} = 255;

 if ($heap->{voltage} > $limit) {
  $kernel->yield("send_cmd", 151);
  $kernel->yield("detect_traffic");
  print "Channel 2 has voltage $heap->{voltage}\n";
  return;
 }
 $time2 = time;

# $kernel->yield("trigger_zm");
 $kernel->yield("calculate_speed");
}

sub calculate_speed {
 print "Calculating speed...";
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 my $time = $time2 - $time1;
 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 print "Speed is $mph mph\n";
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
 my ($kernel, $heap, $arg) = @_[KERNEL, HEAP, ARG0];
 select((select($PORT), $|=1)[0]);
 select(undef,undef,undef,.1);
 print $PORT chr(254);
 if ($arg >= 100 && $arg <= 115) { # Switch a relay.  No response.
  print $PORT chr($arg);
  print $PORT chr($bank);
 } elsif ($arg >= 150 && $arg <= 157) { # Read a channel.  Response.
  print $PORT chr($arg);
  print "Argument is $arg\n";
  my $response = ord(getc($PORT));
  print "Response was $response\n";
  $heap->{voltage} = $response;
  
 }
}
