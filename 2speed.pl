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
my $distance = 8.3; # Distance in feet between pucks
my $polltime = .032;
my ($time1, $time2);
my $limit = 45;
my $baud = 115200;
my $timeout = 2; # Poll puck 2 for only this long
my $voltage = 255;

system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $dev") == 0 || die($!);
open(my $DEV, "+<", $dev) || die($!);

while ($voltage > $limit) {
 print "Pollling 1...\n";
 &Poll(0);
 print "1 is $voltage\n";
}
print "Setting time1...\n";
$time1 = time;
print "Time1 is $time1\n";
$voltage = 255;


while ($voltage > $limit) {
 print "Polling 2...\n";
 &Poll(1);
 print "2 is $voltage\n";
}
print "Setting time2...\n";
$time2 = time;
print "Time2 is $time2\n";

&CalculateSpeed();


sub Poll {
 select(undef,undef,undef,$polltime);
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
