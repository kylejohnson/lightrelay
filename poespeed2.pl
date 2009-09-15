#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);
use POE;

my $dev = shift;
my $distance = 8.3; # Distance in feet between pucks
my $polltime = .032;
my ($time1, $time2);
my $limit = 45;

POE::Session->create(
  inline_states => {
    _start          => \&poll_puck_1,
    poll_puck_1     => \&poll_puck_1,
    poll_puck_2     => \&poll_puck_2,
    calculate_speed => \&calculate_speed,
    poll_a_puck     => \&poll_a_puck,
  },
);

open(my $DEV, "+<", $dev);
POE::Kernel->run();
close($DEV);
exit;

sub poll_puck_1 {
  $_[KERNEL]->yield(
    poll_a_puck => {
      puck        => 1,
      limit       => $limit,
      below_event => "poll_puck_2",
      above_event => "poll_puck_1",
    },
  );
 $time1 = time;
}

sub poll_puck_2 {
  $_[KERNEL]->yield(
    poll_a_puck => {
      puck        => 2,
      limit       => $limit,
      below_event => "calculate_speed",
      above_event => "poll_puck_2",
    },
  );
 $time2 = time;
}

sub poll_a_puck {
  my $arg = $_[ARG0];

#  print int(time), ": Polling puck $arg->{puck}.\n";

  my $cmd = 149 + $arg->{puck};
  print $DEV chr(254);
  print $DEV chr($cmd);
  my $voltage = ord(getc($DEV));

#  my $voltage = int(rand 256);
#  print int(time), ": Puck $arg->{puck} voltage = $voltage\n";

  if ($voltage > $arg->{limit}) {
    $_[KERNEL]->delay($arg->{above_event} => $polltime);
    return;
  }

  # Try again in 1 second.
  $_[KERNEL]->delay($arg->{below_event} => $polltime);
}

sub calculate_speed {
  print scalar time, ": Calculating speed...\n";
  my $time = $time2 - $time1;
  print "Time diff is $time\n";

 my $fps = $distance / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);
 print "$mph mph\n\n";


  $_[KERNEL]->delay(poll_puck_1 => 1);
}

