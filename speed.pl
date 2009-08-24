#!/usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";
our $distance = 12; # Distance in feet between pucks
our $polltime = .03125; # Time between each poll
our $cmd = chr(254);
our ($chan0, $chan1, $time0, $time1);
our $timeout = 4;

open(my $DEV, "+<", $port) || die "can't open $port: $!";

&Poll(0);

if ($chan0 < 50) { # Puck 1 has detected a vehicle
 my $time = time;
 while (($time - time) <= $timeout) { # Start polling puck2 for $timeout
  &Poll(1);
  if ($chan1 < 50) { # Puck 2 is alarmed
   &CalculateSpeed();
  } else {
   select(undef,undef,undef,$polltime);
  }
 }
} else {
 &Poll();
}

sub CalculateSpeed{
 my $time = $time1 - $time0;
 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 print "$mph\n";
}

sub Poll {
 my $channel = 150 + $_[0];
 print $DEV $cmd;
 print $DEV $channel;
 if ($channel == 150) {
  $chan0 = ord(getc($DEV));
  $time0 = time;
 } elsif ($channel == 151) {
  $chan1 = ord(getc($DEV));
  $time1 = time;
 }
}

close($DEV);
