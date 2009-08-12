#!/usr/bin/perl

use strict;
use warnings;
use Fcntl;

my $port = "/dev/ttyS0";
my $PORT;

sysopen($PORT, $port, O_RDWR | O_NONBLOCK) || die "can not open $port: $!\n";
select((select($PORT), $|=1)[0]); # Make $PORT hot

print $PORT chr(254); # 254 tells the device to listen for commands
print $PORT chr(27); # 27 enables reporting and should send back 85
sleep(1);
my $char = getc($PORT) || die "error! $!"; # Get the respond (85)
print ord($char) . "\n"; # Print the response

close($PORT);
