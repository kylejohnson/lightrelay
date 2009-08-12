#!/usr/bin/perl

use strict;
use warnings;
use Fcntl;
use IO::Select;

my $port = "/dev/ttyS0";
my $PORT;
my $read_set = new IO::Select();
my $line;

sysopen($PORT, $port, O_RDWR | O_NONBLOCK) || die "can not open $port: $!\n";
select((select($PORT), $|=1)[0]); # Make $PORT hot

print $PORT chr(254); # 254 tells the device to listen for commands
print $PORT chr(27); # 27 enables reporting and should send back 85

$read_set->add($PORT);
while (1) {
 my ($rh_set) = IO::Select->select($read_set, undef, undef, 0);
 foreach my $rh (@$rh_set) {
  if ($rh != $PORT) {
    sysread($rh, $line, 8);
    print $line;
   }
  }
 }

#my $char = getc($PORT) || die "error! $!"; # Get the respond (85)
#print ord($char) . "\n"; # Print the response

close($PORT);
