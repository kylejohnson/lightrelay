#!/usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";
our $distance = 12; # Distance between pucks
our $polltime = .03125; # Time between each poll
our $cmd = chr(254);
our ($chan1, $chan2, $time1, $time2);
our $timeout = 4;

open(my $DEV, "+<", $port) || die "can't open $port: $!";

# Get the status of puck 1
print $DEV $cmd;
print $DEV chr(150);
$chan1 = ord(getc($DEV));
$time1 = time;

if ($chan1 > 500) { # Puck 1 has detected a vehicle
 my $time = time;
 while (($time - time) <= $timeout) { # Start polling puck2 for $timeout
  print $DEV $cmd;
  print $DEV chr(151);
  $chan2 = ord(getc($DEV)); 
  $time2 = time;
  if ($chan2 > 50) { # Puck 2 is alarmed
   &CalculateSpeed();
  }
 }
}
&CalculateSpeed();
sub CalculateSpeed{
 my $time11 = time;
 my $time22 = time + .1;
 my $time = $time22 - $time11;
 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 print "$mph\n";
}

close($DEV);
