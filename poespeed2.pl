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
my $polltime = .04;
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

POE::Session->create(
  inline_states => {
    _start          => \&server_start,
    do_stuff	    => \&do_stuff,
    got_log_line    => \&got_log_line,
    poll_chan_1     => \&poll_chan_1,
    poll_chan_2     => \&poll_chan_2,
    poll_chan_3     => \&poll_chan_3,
    poll_chan_4     => \&poll_chan_4,
    calculate_speed_1 => \&calculate_speed_1,
    calculate_speed_2 => \&calculate_speed_2,
    parse_logfile => \&parse_logfile,
    poll_a_chan     => \&poll_a_chan,
    trigger_zm	=> \&trigger_zm,
  },
);

open(my $DEV, "+<", $dev) || die("Failed opening $dev: $!\n");
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

sub server_start {
 $_[HEAP]->{current_1} = "poll_chan_1";
 $_[HEAP]->{current_2} = "poll_chan_3";
 $_[KERNEL]->yield("poll_chan_1");
 $_[KERNEL]->yield("poll_chan_3");
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

 $_[KERNEL]->yield("poll_a_chan" => {chan => $off});
 $_[KERNEL]->delay("poll_a_chan", .3, {chan => $on});
}

sub poll_chan_1 {
  if ($_[HEAP]->{current_1} ne "poll_chan_1") {
    $_[HEAP]->{current_1} = "poll_chan_1";
#    $_[HEAP]->{start_time_1} = time();
  }

  $_[KERNEL]->yield(
    poll_a_chan => {
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
    poll_a_chan => {
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
    poll_a_chan => {
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
    poll_a_chan => {
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

sub poll_a_chan {
 my $arg = $_[ARG0];
 my $chan = $arg->{chan};
 my $time = localtime(time);

 if ($chan >= 100 && $chan < 115) { # Switch a relay
  my $cmd = $chan;
  print $DEV chr(254);
  print $DEV chr($cmd);
  print $DEV chr(1);
 } else { # Poll a channel
  my $cmd = 149 + $chan;
  if (exists $arg->{timeout}) {
   if ($chan <= 2) {
    if (time() - $_[HEAP]->{start_time_1} >= $arg->{timeout}) {
     print $time, ": Timed out polling chan $arg->{chan}!\n";
     $_[KERNEL]->yield($arg->{timeout_event});
     return;
    }
   } elsif ($chan >= 3 && $chan < 10) {
    if (time() - $_[HEAP]->{start_time_2} >= $arg->{timeout}) {
     print $time, ": Timed out polling chan $arg->{chan}!\n";
     $_[KERNEL]->yield($arg->{timeout_event});
     return;
    }
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
 my $date = localtime(time);

 my $fps = $distance_1 / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);

 print "$date: Lane 1: $mph mph\n";
 if ($color eq 'yellow' || $color eq 'red' && $mph < 150) {
  $_[KERNEL]->yield("trigger_zm", $mph, 1);
 }
 $_[KERNEL]->delay(poll_chan_1 => 1);
}

sub calculate_speed_2 {
 my $time = $time4 - $time3;
 my $date = localtime(time);

 my $fps = ($distance_2 / 12) / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);

 print "$date: Lane 2: $mph mph\n";
 if ($color eq 'yellow' || $color eq 'red' && $mph < 150) {
  $_[KERNEL]->yield("trigger_zm", $mph, 2);
 }
 $_[KERNEL]->delay(poll_chan_3 => 1);
}
