#!/usr/bin/perl

use strict;
use warnings;

my $cmd = shift;

if (!$cmd) {
 die("You must enter a command!\n");
 exit;
}

if ($cmd eq "on") {
 print "Turning relays on...\n";
 $cmd = 130;
}
if ($cmd eq "off") {
 print "Turning relays off...\n";
 $cmd = 129;
}
if ($cmd eq "green") {
 print "Turning $cmd on...\n";
 $cmd = 108;
}
if ($cmd eq "amber") {
 print "Turning $cmd on...\n";
 $cmd = 109;
}
if ($cmd eq "red") {
 print "Turning $cmd on...\n";
 $cmd = 110;
}

open(my $DEV, "+<", "/dev/ttyS0") || die ($!);
 print $DEV chr(254);
 print $DEV chr(129);
 print $DEV chr(1);
 select(undef,undef,undef,.5);
 print $DEV chr(254);
 print $DEV chr($cmd);
 print $DEV chr(1);

 my $result = ord(getc($DEV));
 print "$result\n";
close($DEV);
