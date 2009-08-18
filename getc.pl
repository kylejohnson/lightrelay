#!/usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";

open (SERIALPORT, "+<", "$port") or die "can't open $port. ";
print SERIALPORT chr(254);
print SERIALPORT chr(27);
my $result = getc(SERIALPORT);
print ord($result) . "\n";

close (SERIALPORT);
