#!/usr/bin/perl

use strict;
use warnings;

open(my $FILE, ">>", "dbgpipe.log") || die($!);
select((select($FILE), $| = 1)[0]);
while () {
 print $FILE "Amber alarmed\n";
 sleep(3);
 print $FILE "Red alarmed\n";
 sleep(3);
 print $FILE "Green alarmed\n";
 sleep(3);
}
close($FILE);
