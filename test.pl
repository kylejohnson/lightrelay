#!/usr/bin/perl

use strict;
use warnings;

my $cmd = shift;
my @cmds = qw(on off green amber red test cycle);
my $dev = "/dev/ttyS0";
my $timeout = 2;
my $bank = 1;
my $baud = 115200;

if (!$cmd) {
 die("You must enter a command!\n");
 exit;
}

if ($cmd eq "test") {
 print "Testing 2-way communication with $dev!\n";
 # We want to first set the baud to 38400, send a command, and if we receive a response,
 # let us know, then continue testing each relay.
 # If not, move on to 115200 and do the same thing.
 stty($baud);
 my $answer = send_cmds(27); # I might want to send 34 instead - test.
 if ($answer != 85) {
  print "Communications with $dev failed at $baud.\n";
  $baud = 38400;
  stty($baud);
  $answer = send_cmds(27); # I might want to send 34 instead - test.
  if ($answer != 85) {
   print "Communications with $dev failed at $baud.\n";
   print "Communications failed at both 115200 and 38400!\n";
   print "Maybe the device is broken, or is not connected.\n";
   print "Exiting...\n";
   exit;
  } else {
   test_relays();
  }
 } else {
  test_relays();
 }
}

if ($cmd eq "green") {
 send_cmds(108);
}

if ($cmd eq "amber") {
 send_cmds(109);
}

if ($cmd eq "red") {
 send_cmds(110);
}

if ($cmd eq "on") {
 send_cmds(130);
}

if ($cmd eq "off") {
 send_cmds(129);
}


sub test_relays {
 print "Communications succedded at $baud!  Testing indivudual relays...\n";
 my @answers = send_cmds(108, 109, 110, 100, 101, 102);
 foreach (@answers) {
  print "$_\n";
 }
}

sub send_cmds {
 my $answer;
 my @answers;
 foreach my $cmd (@_) {
  sleep(1);
  local $SIG{ALRM} = sub{die "Timed out while trying to communicate at $baud...\n"};
  eval {
   alarm $timeout;
   open(my $DEV, "+<", $dev) || die ($!);
    print $DEV chr(254);
    if ($cmd == 27) {
     print $DEV chr($cmd);
    } else {
     print $DEV chr($cmd);
     print $DEV chr($bank);
    }
    $answer = ord(getc($DEV));
    push @answers, $answer;
   close($DEV);
   alarm 0;
  }
 }
 if ($cmd = 27 && $answer) {
  return $answer;
 } elsif (@answers) {
  return @answers;
 } else {
  return 0;
 }
}

sub stty {
 my $baud = shift;
 print "Setting baud rate to $baud...\n";
 system("/bin/stty $baud ignbrk -brkint -icrnl -imaxbel -opost -isig -icanon -iexten -echo -F $dev") == 0 || die($!);
}
