#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);

my $dev = "/dev/ttyS0";
my $distance_1 = 90; # In feet
my $distance_2 = 90; # Inch
my $polltime = .03;
my ($time1, $time2, $time3, $time4);
my $limit = 45;
my $timeout = 2;

# This session will handle polling channels 1 and 2 (lane 1).
POE::Session->create(
  inline_states => {
    _start          => \&start_lane_1,
    poll_chan_1     => \&poll_chan_1,
    poll_chan_2     => \&poll_chan_2,
    calculate_speed_1 => \&calculate_speed_1,
    poll_lane_1     => \&poll_lane_1,
  },
);

# This session will handle polling channels 3 and 4 (lane 2).
POE::Session->create(
  inline_states => {
    _start          => \&start_lane_2,
    poll_chan_3     => \&poll_chan_3,
    poll_chan_4     => \&poll_chan_4,
    calculate_speed_2 => \&calculate_speed_2,
    poll_lane_2     => \&poll_lane_2,
  },
);

open(my $DEV, "+<", $dev) || die("Failed opening $dev: $!\n");
select((select($DEV), $| = 1)[0]);
POE::Kernel->run();
close($DEV);
exit;

sub start_lane_1 {
 $_[HEAP]->{current_1} = "poll_chan_1";
 $_[KERNEL]->yield("poll_chan_1");
}

sub start_lane_2 {
 $_[HEAP]->{current_2} = "poll_chan_3";
 $_[KERNEL]->yield("poll_chan_3");
}

sub poll_chan_1 {
  if ($_[HEAP]->{current_1} ne "poll_chan_1") {
    $_[HEAP]->{current_1} = "poll_chan_1";
#    $_[HEAP]->{start_time_1} = time();
  }

  $_[KERNEL]->yield(
    poll_lane_1 => {
      chan        => 1,
      limit       => $limit,
      below_event => "poll_chan_2",
      above_event => "poll_chan_1",
    },
  );
 $time1 = time;
}

sub poll_chan_2 {
  if ($_[HEAP]->{current_1} ne "poll_chan_2") {
    $_[HEAP]->{current_1} = "poll_chan_2";
    $_[HEAP]->{start_time_1} = time();
  }

 $_[KERNEL]->yield(
    poll_lane_1 => {
      chan        => 2,
      limit       => $limit,
      below_event => "calculate_speed_1",
      above_event => "poll_chan_2",
      timeout	=> 2,
      timeout_event => "poll_chan_1",
    },
  );
 $time2 = time;
}

sub poll_chan_3 {
  if ($_[HEAP]->{current_2} ne "poll_chan_3") {
    $_[HEAP]->{current_2} = "poll_chan_3";
#    $_[HEAP]->{start_time_2} = time();
  }

  $_[KERNEL]->yield(
    poll_lane_2 => {
      chan        => 3,
      limit       => $limit,
      below_event => "poll_chan_4",
      above_event => "poll_chan_3",
    },
  );
 $time3 = time;
}

sub poll_chan_4 {
  if ($_[HEAP]->{current_2} ne "poll_chan_4") {
    $_[HEAP]->{current_2} = "poll_chan_4";
    $_[HEAP]->{start_time_2} = time();
  }

  $_[KERNEL]->yield(
    poll_lane_2 => {
      chan        => 4,
      limit       => $limit,
      below_event => "calculate_speed_2",
      above_event => "poll_chan_4",
      timeout	=> 2,
      timeout_event => "poll_chan_3",
    },
  );
 $time4 = time;
}

sub poll_lane_1 {
 my $arg = $_[ARG0];
 my $chan = $arg->{chan};
 my $time = localtime(time);
 my $cmd = 149 + $chan;

 if (exists $arg->{timeout}) {
  if (time() - $_[HEAP]->{start_time_1} >= $arg->{timeout}) {
   print $time, ": Timed out polling chan $arg->{chan}!\n";
   $_[KERNEL]->yield($arg->{timeout_event});
   return;
  }
 }

 print $DEV chr(254);
 print $DEV chr($cmd);
 my $voltage = ord(getc($DEV));

 if ($voltage > $arg->{limit}) {
  $_[KERNEL]->delay($arg->{above_event} => $polltime);
  return;
 } else {
  $_[KERNEL]->delay($arg->{below_event} => $polltime);
 }
}

sub poll_lane_2 {
 my $arg = $_[ARG0];
 my $chan = $arg->{chan};
 my $time = localtime(time);
 my $cmd = 149 + $chan;

 if (exists $arg->{timeout}) {
  if (time() - $_[HEAP]->{start_time_2} >= $arg->{timeout}) {
   print $time, ": Timed out polling chan $arg->{chan}!\n";
   $_[KERNEL]->yield($arg->{timeout_event});
   return;
  }
 }

 print $DEV chr(254);
 print $DEV chr($cmd);
 my $voltage = ord(getc($DEV));

 if ($voltage > $arg->{limit}) {
  $_[KERNEL]->delay($arg->{above_event} => $polltime);
  return;
 } else {
  $_[KERNEL]->delay($arg->{below_event} => $polltime);
 }
}

sub calculate_speed_1 {
 my $time = $time2 - $time1;
 my $lane = 1;
 my $fps = ($distance_1 / 12 ) / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);
 my $date = localtime(time);

 print "$date: Lane $lane: $mph mph\n";

 $_[KERNEL]->delay(poll_chan_1 => 1);
}

sub calculate_speed_2 {
 my $time = $time4 - $time3;
 my $lane = 2;
 my $fps = ($distance_2 / 12) / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);
 my $date = localtime(time);

 print "$date: Lane $lane: $mph mph\n";

 $_[KERNEL]->delay(poll_chan_3 => 1);
}
