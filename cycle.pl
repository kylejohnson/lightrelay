#! /usr/bin/perl

use strict;
use warnings;
use Term::Screen;

my $port = "/dev/ttyUSB0";
my $count = 150;
my $cmd = chr(254);
my $cycle = 1;
my $channel = 0;
my $voltage;
my $chans = shift;
our $polltime = .032;
my $baud = 115200;
my $row = 0;

system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $port") == 0 || die "Can't stty: $!\n";
open(my $DEV, "+<", $port) || die "Can't open $port: $!\n";

while ($count < (150 + $chans)) {
 print $DEV chr(254);
 my $cmd = (150 + $chans) - 1;
 print $DEV chr($cmd);
 my $result = ord(getc($DEV));

 if ($result == 255) {
  $voltage = 0;
 } else {
  $voltage = ($result * 0.019607);
 }

 my $scr = new Term::Screen;
 $scr->clrscr();
 $scr->at($row,0);
 $scr->puts(printf "Channel $channel:\t " . $voltage . " Volts ($result)");

 $channel++;
 $row++;
 $count++;
 
 if ($count == (150 + $chans)) {
 $count = 150;
 $channel = 1;
 $row = 0;
 }
}

close($DEV);
