#!/usr/bin/perl

use strict;
use warnings;
use Device::SerialPort;

my $portName = "/dev/ttyS0";
my $portObj = new Device::SerialPort($portName) || die "Can't open $portName: $!\n";
my $cmd1 = chr(254);
my $cmd2 = chr(27);

$portObj->baudrate(115200);
$portObj->parity("none");
$portObj->databits(8);
$portObj->stopbits(1);
$portObj->handshake("none");

$portObj->write_settings;

$portObj->write($cmd1);
$portObj->write($cmd2);
$portObj->are_match(85);

my $gotit = $portObj->lookfor;

print $gotit;
