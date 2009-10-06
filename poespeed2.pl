#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);
use POE qw(Wheel::FollowTail);
use IO::Socket;
use Term::ANSIColor;

my $color = 'green';
my $creepspeed1 = 5;
my $creepspeed2 = 5;
my $dev = "/dev/ttyS0";
my $distance_1 = 8.3; # In feet
my $distance_2 = 128; # Inch
my $polltime = .03;
my ($time1, $time2, $time3, $time4);
my $limit = 45;
my $logfile = "dbgpipe.log";
my $on_green = 108;
my $off_green = 100;
my $on_amber = 109;
my $off_amber = 101;
my $on_red = 110;
my $off_red = 102;
my $timeout = 2;

# This session will handle polling channels 1 and 2 (lane 1).
POE::Session->create(
  inline_states => {
    _start          => \&server_start1,
    poll_chan_1     => \&poll_chan_1,
    poll_chan_2     => \&poll_chan_2,
    calculate_speed_1 => \&calculate_speed_1,
    poll_lane_1     => \&poll_lane_1,
    trigger_zm	=> \&trigger_zm,
  },
);

# This session will handle polling channels 3 and 4 (lane 2).
POE::Session->create(
  inline_states => {
    _start          => \&server_start3,
    poll_chan_3     => \&poll_chan_3,
    poll_chan_4     => \&poll_chan_4,
    calculate_speed_2 => \&calculate_speed_2,
    poll_lane_2     => \&poll_lane_2,
    trigger_zm	=> \&trigger_zm,
  },
);

# This session will handle parsing log and switching relays.
POE::Session->create(
 inline_states => {
  _start	=> \&server_start2,
  do_stuff	    => \&do_stuff,
  parse_logfile	=> \&parse_logfile,
  got_log_line    => \&got_log_line,
  switch_relay	=> \&switch_relay,
 }
);

open(my $DEV, "+<", $dev) || die("Failed opening $dev: $!\n");
select((select($DEV), $| = 1)[0]);
my $sock = new IO::Socket::INET (
 PeerAddr => 'localhost',
 PeerPort => '6802',
 Proto => 'tcp',
);
die("Failed opening ZM Socket: $!\n") unless ($sock);
POE::Kernel->run();
close($DEV);
close($sock);
exit;

sub server_start1 {
 $_[HEAP]->{current_1} = "poll_chan_1";
 $_[KERNEL]->yield("poll_chan_1");
}

sub server_start3 {
 $_[HEAP]->{current_2} = "poll_chan_3";
 $_[KERNEL]->yield("poll_chan_3");
}

sub server_start2 {
 $_[KERNEL]->yield("parse_logfile");
}

sub parse_logfile {
 $_[HEAP]->{tailor} = POE::Wheel::FollowTail->new (
  Filename => "$logfile",
  InputEvent => "got_log_line",
 );
}

sub got_log_line {
 my ($kernel, $heap, $line) = @_[KERNEL, HEAP, ARG0];

 if ($line =~ /Green.*alarmed/ && $color eq 'red') # Color is red; green alarms...
 {
  $kernel->yield("do_stuff", $off_red, $on_green, 'green', 'Green');
 }
 elsif ($line =~ /LG.*alarmed/ && $color eq 'red') # Color is red; left green alarms...
 {
  $kernel->yield("do_stuff", $off_red, $on_green, 'green', 'Left Green');
 }
 elsif ($line =~ /Amber.*alarmed/ && $color eq 'green') # Color is green; amber alarms...
 {
  $kernel->yield("do_stuff", $off_green, $on_amber, 'yellow', 'Amber');
 }
 elsif ($line =~ /Red.*alarmed/ && $color eq 'yellow') # Color is amber; red alarms...
 {
  $kernel->yield("do_stuff", $off_amber, $on_red, 'red', 'Red');
 }
}

sub do_stuff {
 my ($kernel, $heap, $off, $on, $arg2, $state) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2, ARG3];
 $color = $arg2;
 print color("$color"), "Color is now $color\n";

 $_[KERNEL]->yield("switch_relay" => {cmd => $off});
 $_[KERNEL]->delay("switch_relay", .3, {cmd => $on});
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

sub switch_relay {
# print "Switching relay...\n";
 my $arg = $_[ARG0];
 my $cmd = $arg->{cmd};
# print "Sending 254\n";
 print $DEV chr(254);
# print "Sending $cmd\n";
 print $DEV chr($cmd);
# print "Sending 1\n";
 print $DEV chr(1);
}

sub poll_lane_1 {
# print "Polling lane 1...\n";
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

# print "Lane 1: Sending 254\n";
 print $DEV chr(254);
# print "Lane 1: Sending $cmd\n";
 print $DEV chr($cmd);
# print "Lane 1: Getting voltage\n";
 my $voltage = ord(getc($DEV));
# print "Lane 1: Voltage is $voltage\n";

 if ($voltage > $arg->{limit}) {
  $_[KERNEL]->delay($arg->{above_event} => $polltime);
  return;
 } else {
  $_[KERNEL]->delay($arg->{below_event} => $polltime);
 }
}

sub poll_lane_2 {
# print "Polling lane 2...\n";
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

# print "Lane 2: Sending 254\n";
 print $DEV chr(254);
# print "Lane 2: Sending $cmd\n";
 print $DEV chr($cmd);
# print "Lane 2: Getting voltage\n";
 my $voltage = ord(getc($DEV));
# print "Lane 2: Voltage is $voltage\n";

 if ($voltage > $arg->{limit}) {
  $_[KERNEL]->delay($arg->{above_event} => $polltime);
  return;
 } else {
  $_[KERNEL]->delay($arg->{below_event} => $polltime);
 }
}

sub trigger_zm {
 print "Triggering ZM...\n";
 #my $mph = $_[ARG0] . "mph -";
 #my $lane = $_[ARG1];
 #if ($lane == 1) {
 # print $sock "7|on+6|1|Lane $lane Violation|Lane $lane - $mph|$mph $lane";
 #} elsif ($lane == 2) {
 # print $sock "5|on+6|1|Lane $lane Violation|Lane $lane - $mph|$mph $lane";
 #}
}

sub calculate_speed_1 {
 my $time = $time2 - $time1;
 my $lane = 1;
 my $fps = $distance_1 / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);
 my $date = localtime(time);

 print "$date: Lane $lane: $mph mph\n";

 if ($color eq 'yellow' || $color eq 'red' && $mph < 150) {
  $_[KERNEL]->yield("trigger_zm", $mph, 1);
 }
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

 if ($color eq 'yellow' || $color eq 'red' && $mph < 150) {
  $_[KERNEL]->yield("trigger_zm", $mph, 2);
 }
 $_[KERNEL]->delay(poll_chan_3 => 1);
}

sub determine_violation {
 my $mph = $_[ARG0];
 my $lane = $_[ARG1];
 my $date = localtime(time);

 print "$date: Lane $lane: $mph mph\n";

 if ($color eq 'yellow' || $color eq 'red' && $mph < 150) {
  $_[KERNEL]->yield("trigger_zm", $mph, 2);
 }
 $_[KERNEL]->delay(poll_chan_3 => 1);
}
