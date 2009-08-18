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
 my $result = ord(getc($DEV));
 if ($result == 255) {
  my $voltage = 0;
  print $voltage . " Volts\n";
 } else {
  my $voltage = ($result * 0.019607);
  print $voltage . " Volts\n";
 }
 $count++;
}
close($DEV);
