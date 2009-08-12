#!/usr/bin/perl

# Trying out getc.

use strict;
use warnings;
use Fcntl;

my $port = "/dev/ttyS0";
my $PORT;

sysopen($PORT, $port, O_RDWR | O_NOCTTY | O_NDELAY | O_NONBLOCK);

print $PORT chr(254);
print $PORT chr(27); # 27 enables reporting - should send back 85

my $char = getc($PORT);
print ord($char);

close($PORT);
