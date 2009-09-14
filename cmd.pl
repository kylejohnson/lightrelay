#!/usr/bin/perl

use strict;
use warnings;

my $cmd = shift;
my $dev = "/dev/ttyUSB0";
my $on = 30;
my $off = 29;

if (!$cmd || $cmd !~ /^(?:on|off)$/) {
 print "Error!!  Format is \"cmd.pl on | off\"\n";
 exit;
}

open(my $DEV, "+<", $dev) || die($!);
print $DEV chr(254);
if ($cmd eq 'on') {
 print $DEV chr($on);
} elsif ($cmd eq 'off') {
 print $DEV chr($off);
} elsif ($cmd == 1) {

} elsif ($cmd == 2) {

} elsif ($cmd == 3) {

} elsif ($cmd == 4) {

} elsif ($cmd == 5) {

} elsif ($cmd == 6) {

} elsif ($cmd == 7) {

} elsif ($cmd == 8) {

}
close($DEV);
