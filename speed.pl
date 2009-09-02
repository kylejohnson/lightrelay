#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);

my $port = "/dev/ttyUSB0";
our $distance = 12; # Distance between pucks
#our $polltime = .03125; # Time between each poll
our $polltime = .05; # Time between each poll
our ($chan1, $chan2, $time1, $time2);
our $timeout = 4;

open(my $DEV, "+<", $port) || die "can't open $port: $!";

&Poll1(); # Get the status of puck 1

while (1 == 1) {
if ($chan1 <= 130 && $chan1 != 255) { # Puck 1 has detected a vehicle
 my $time = time;
 while ((time - $time) <= $timeout) { # Start polling puck2 for $timeout
  print $DEV chr(254);
  print $DEV chr(151);
  $chan2 = ord(getc($DEV)); 
  $time2 = time;
  if ($chan2 <= 130 && $chan2 != 255) { # Puck 2 has detected a vehicle
   &CalculateSpeed();
  } else {
   select(undef,undef,undef,$polltime);
  }
 }
} else {
 select(undef,undef,undef,.1);
 &Poll1();
}
}

sub CalculateSpeed{
 print "time1 $time1\n";
 print "time2 $time2\n";
 my $time = $time2 - $time1;
 print "time $time\n";
 my $fps = $distance / $time;
 print "fps $fps\n";
 my $mph = (($fps * 60) * 60) / 5280;
 print "mph $mph\n\n";
}

sub Poll1{
 print $DEV chr(254);
 print $DEV chr(150);
 $chan1 = ord(getc($DEV));
 $time1 = time;
}

close($DEV);
