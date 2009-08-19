#!/usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";
our $distance = 12; # Distance between pucks
our $polltime = .03125; # Time between each poll
our $cmd = chr(254);
our ($chan1, $chan2, $time1, $time2);

open(my $DEV, "+<", $port) || die "can't open $port: $!";

# Get the status of puck 1
print $DEV $cmd;
print $DEV chr(150);
$chan1 = ord(getc($DEV));
$time1 = time;

 print $DEV $cmd;
 print $DEV chr(151);
 $chan2 = ord(getc($DEV)); 
 $time2 = time;

print "$chan1\t$chan2";

close($DEV);
