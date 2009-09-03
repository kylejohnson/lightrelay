#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);

my $time1 = time;
print "$time1\n";

sleep(1);

my $time2 = time;
print "$time2\n";
