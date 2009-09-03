#!/usr/bin/perl

#
# This script is used to poll an ADSSR4xPROXR device, which is connected to
# external sensys equipment, which is used to detect the presense of vehicles.
# The "pucks" are the sensys equipement which is in the pavement.  Pucks
# relay to an access point, which connects to our PROXR board.  Each puck
# has it's own channel (P1 -> C1; P2 -> C2).  When a puck is not detecting
# a vehicle, it outputs ~3.8v.  When a vehicle is detected, the puck outputs
# <~.5v.  So when P1 voltage drops below 130 (how PROXR reports voltages,
# before the Analog to Digital (A2D) conversion), record $time1, start polling
# P2.  When P2 drops below 130, record $time2, and then calculate the speed
# of the vehicle.
#

use strict;
use warnings;
use Time::HiRes qw(time);

my $dev = "/dev/ttyUSB0";
my $distance = 12; # Distance in feet between pucks
my $polltime = .032;
my ($voltage, $time1, $time2);

open(my $DEV, "+<", $dev) || die($!);

&Poll(0); # Poll puck 1

while (1 == 1) { # Loop
 if ($voltage <= 130 && $voltage != 255) { # Puck 1 voltage is <= 130
  $time1 = time;
  &Poll(1); # Poll puck 2
  if ($voltage <= 130 && $voltage != 255) { # Puck 2 voltage is <= 130
   $time2 =  time;
   &CalculateSpeed();
  } else {
   select(undef,undef,undef,$polltime);
   &Poll(1); # Poll puck 2 again
  }
 } else {
  select(undef,undef,undef,.1);
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
 my $time = $time2 - $time1;
 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 print "$mph mph\n";
}

close($DEV);
