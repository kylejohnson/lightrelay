#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);
use POE;

my $dev = shift;
my $distance_1 = 8.3; # Distance in feet between pucks
my $distance_2 = 8.3; # Distance in feet between pucks
my $polltime = .032;
my ($time1, $time2);
my $limit = 45;
my $baud = 115200;
my $timeout = 2; # Poll puck 2 for only this long
#my $voltage = 255;

system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $dev") == 0 || die($!);
open(my $DEV, "+<", $dev) || die($!);

POE::Session->create(
 inline_states => {
  _start => \&detect_traffic,
  detect_traffic => \&detect_traffic,
  calculate_speed => \&calculate_speed,
  poll => \&poll,
 },
);

POE::Kernel->run();
exit;

sub detect_traffic {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 print "$heap->{voltage}\n";

 if ($heap->{voltage} > $limit) {
# if ($voltage > $limit) {
  $kernel->yield("poll", 0);
#  $kernel->yield("detect_traffic");
  return;
 }
 $time1 = time;
 $heap->{voltage} = 255;
 #$voltage = 255;

 if ($heap->{voltage} > $limit) {
# if ($voltage > $limit) {
  $kernel->yield("poll", 1);
#  $kernel->yield("detect_traffic");
  return;
 }
 $time2 = time;
 print "Am I getting here?\n";
 $kernel->yield("calculate_speed");
 return;
}

sub poll {
 my ($kernel, $heap, $arg) = @_[KERNEL, HEAP, ARG0];
 select(undef,undef,undef,$polltime);
 my $cmd = 150 + $arg;
 print $DEV chr(254);
 print $DEV chr($cmd);
 $heap->{voltage} = ord(getc($DEV));
 #$voltage = ord(getc($DEV));
 print "$cmd is $heap->{voltage}\n";
  $kernel->yield("detect_traffic");
}

sub calculate_speed {
 my ($kernel, $heap) = @_[KERNEL, HEAP];
 print "Calculating speed...\n";
 my $time = $time2 - $time1;
 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);
 print "$mph mph\n\n";
 $heap->{voltage} = 255;
 #$voltage = 255;
 sleep(1);
 $kernel->yield("detect_traffic");
}

close($DEV);
