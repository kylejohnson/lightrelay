#!/usr/bin/perl

#
# This script is used to poll an ADSSR4xPROXR device, which is connected to
# external sensys equipment, which is used to detect the presense of vehicles.
# The "pucks" are the sensys equipement which is in the pavement.  Pucks
# relay to an access point, which connects to our PROXR board.  Each puck
# has it's own channel (P1 -> C1; P2 -> C2).  When a puck is not detecting
# a vehicle, it outputs ~3.8v.  When a vehicle is detected, the puck outputs
# <~.5v.  So when P1 voltage drops below $limit (how PROXR reports voltages,
# before the Analog to Digital (A2D) conversion), record $time1, start polling
# P2.  When P2 drops below $limit, record $time2, and then calculate the speed
# of the vehicle.
#

use strict;
use warnings;
use Time::HiRes qw(time);

my $dev = "/dev/ttyS0";
my $distance = 12; # Distance in feet between pucks
my $polltime = .032;
my ($voltage, $time1, $time2);
my $limit = 45;
my $baud = 115200;

system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $dev") == 0 || die "$!\n";
open(my $DEV, "+<", $dev) || die($!);

&Poll(0); # Poll puck 1

while () { # Loop
 if ($voltage <= $limit && $voltage != 255) {
  print "voltage1 " . $voltage * 0.019607 . "\n";
  $time1 = time;
  &Poll(1); # Poll puck 2
  if ($voltage <= $limit && $voltage != 255) {
  print "voltage2 " . $voltage * 0.019607 . "\n";
   $time2 =  time;
   &CalculateSpeed();
  } else {
   select(undef,undef,undef,$polltime);
   &Poll(1); # Poll puck 2 again
  }
 } else {
  select(undef,undef,undef,$polltime);
  &Poll(0); # Poll puck 1 again
 }
}

sub Poll {
 my $cmd = 150 + $_[0];
 print $DEV chr(254);
 print $DEV chr($cmd);
 $voltage = ord(getc($DEV));
}

sub CalculateSpeed {
 print "time1 $time1\n";
 print "time2 $time2\n";
 my $time = $time2 - $time1;
 print "time $time\n";
 my $fps = $distance / $time;
 print "fps $fps\n";
 my $mph = (($fps * 60) * 60) / 5280; # Or just $fps * .682?
 print "$mph mph\n\n";
}

close($DEV);
