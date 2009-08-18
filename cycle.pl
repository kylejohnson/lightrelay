#! /usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";
my $count = 150;
my $cmd = chr(254);

open(my $DEV, "+<", $port) || die "Can't open $port: $!\n";
while ($count <= 157) {
 print $DEV $cmd;
 print $DEV chr($count);
 my $result = getc($DEV);
 print ord($result) . "\n";
 $count++;
}
close($DEV);
