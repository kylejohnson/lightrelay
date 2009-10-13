#!/usr/bin/perl

use strict;
use warnings;

my $port = "/dev/ttyS0";
my $cmd = shift;

open (my $SERIALPORT, "+<", "$port") || ($!);
 print $SERIALPORT chr(254);
 print $SERIALPORT chr($cmd);
 my $result = getc($SERIALPORT);
 print ord($result) . "\n";
close ($SERIALPORT);
