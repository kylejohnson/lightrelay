#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);

my $dev = "/dev/ttyUSB0";
my $distance = 8.3; # Distance in feet between pucks
my $polltime = .032;
my ($time1, $time2);
my $limit = 45;
my $baud = 115200;
my $timeout = 2; # Poll puck 2 for only this long
my $voltage = 255;

system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $dev") == 0 || die($!);
open(my $DEV, "+<", $dev) || die($!);

while ($voltage > $limit) {
 &Poll(0);
}
$time1 = time;
$voltage = 255;

while ($voltage > $limit) {
 &Poll(1);
}
$time2 = time;

&CalculateSpeed();


sub Poll {
 select(undef,undef,undef,$polltime);
 my $cmd = 150 + $_[0];
 print $DEV chr(254);
 print $DEV chr($cmd);
 $voltage = ord(getc($DEV));
}

sub CalculateSpeed {
 my $time = $time2 - $time1;
 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 print "$mph mph\n";
}

close($DEV);
