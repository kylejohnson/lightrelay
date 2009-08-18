#! /usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";
my $count = 150;
my $cmd = chr(254);
my $cycle = 1;
my $channel = 0;
our $voltage;

#system("/bin/stty 115200 ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $port") == 0 || die "Can't stty: $!\n";
open(my $DEV, "+<", $port) || die "Can't open $port: $!\n";
while ($count <= 151) {
 if ($count == 150) {
  print "\t $cycle\n";
 }
 print $DEV $cmd;
 print $DEV chr($count);
 my $result = ord(getc($DEV));
 if ($result == 255) {
  $voltage = 0;
 } else {

  $voltage = sprintf("%.2f", ($result * 0.019607));
 }
 printf "Channel $channel:\t " . $voltage . " Volts ($result)\n";
 $count++;
 select(undef,undef,undef,.50);
 $channel++;

if ($count > 151) {
 $count = 150;
 $channel = 0;
 print "\n";
 $cycle++;
 sleep(1);
}
}
close($DEV);
