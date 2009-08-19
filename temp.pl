#!/usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";
my $cmd = chr(254);
my $chan = chr(157);

open(my $DEV, "+<", $port) || die "can't open $port: $!\n";

print $DEV $cmd;
print $DEV $chan;

my $Tc = ord(getc($DEV));
my $Tf = (9/5)*$Tc+32;

print $Tc . "C \t " . $Tf . "F\n";

close($DEV);
