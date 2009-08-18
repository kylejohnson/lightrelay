#! /usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyUSB0";
my $count = 150;
my $cmd = chr(254);
my $cycle = 1;
my $channel = 0;

#system("/bin/stty 115200 ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $port") == 0 || die "Can't stty: $!\n";
open(my $DEV, "+<", $port) || die "Can't open $port: $!\n";
while ($count <= 157) {
 print $DEV $cmd;
 print $DEV chr($count);
 my $result = ord(getc($DEV));
 if ($result == 255) {
  my $voltage = 0;
  print "Channel $channel:\t " . $voltage . " Volts\n";
 } else {
  my $voltage = ($result * 0.019607);
  print "Channel $channel:\t " . $voltage . " Volts\n";
 }
 $count++;
 $channel++;

if ($count > 157) {
 $count = 150;
 $channel = 0;
 print "\t $cycle\n";
 $cycle++;
 sleep(1);
}
}
close($DEV);
