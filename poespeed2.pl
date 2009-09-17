#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);
use POE qw(Wheel::FollowTail);
use IO::Socket;

my $color = 'green';
my $dev = shift;
my $distance_1 = 8.3; # In feet
my $distance_2 = 8.3; # In feet
my $polltime = .032;
my ($time1, $time2, $time3, $time4);
my $limit = 45;
my $logfile = "dbgpipe.log";
my $on_green = 108;
my $off_green = 100;
my $on_amber = 109;
my $off_amber = 101;
my $on_red = 110;
my $off_red = 102;

if (!$dev) {
 print "You must specify the path of the device!\n";
 exit;
}

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
    switch_relay => \&switch_relay,
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
  $kernel->yield("do_stuff", $off_green, $on_amber, 'amber', 'Amber');
 }
 elsif ($line =~ /Red.*alarmed/ && $color eq 'amber') # Color is amber; red alarms...
 {
  $kernel->yield("do_stuff", $off_amber, $on_red, 'red', 'Red');
 }
}

sub do_stuff {
  my ($kernel, $heap, $off, $on, $arg2, $state) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2, ARG3];
 $color = $arg2;
 print "Color is now $color\n";

 $_[KERNEL]->yield("switch_relay" => {chan => $off,});
 $_[KERNEL]->delay("switch_relay", .3, {chan => $on});
}

sub poll_chan_1 {
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
  $_[KERNEL]->yield(
    poll_a_chan => {
      chan        => 2,
      limit       => $limit,
      below_event => "calculate_speed_1",
      above_event => "poll_chan_2",
    },
  );
 $time2 = time;
}

sub poll_chan_3 {
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
  $_[KERNEL]->yield(
    poll_a_chan => {
      chan        => 4,
      limit       => $limit,
      below_event => "calculate_speed_2",
      above_event => "poll_chan_4",
    },
  );
 $time4 = time;
}

sub switch_relay {
 my $arg = $_[ARG0];

 my $cmd =  $arg->{chan};
 print $DEV chr(254);
 print $DEV chr($cmd);
 print $DEV chr(1);
}

sub poll_a_chan {
 my $arg = $_[ARG0];
 my $cmd = 149 + $arg->{chan};

 print $DEV chr(254);
 print $DEV chr($cmd);
 my $voltage = ord(getc($DEV));

 if ($voltage > $arg->{limit}) {
  $_[KERNEL]->delay($arg->{above_event} => $polltime);
  return;
 }

 $_[KERNEL]->delay($arg->{below_event} => $polltime);
}

sub trigger_zm {
 print "Triggering ZM...\n";
 my $mph = $_[ARG0] . "mph -";
 my $lane = $_[ARG1];
 print $sock "5|on+6|1|Speed||$mph $lane";
}

sub calculate_speed_1 {
 my $time = $time2 - $time1;
 my $date = localtime(time);

 my $fps = $distance_1 / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);

 print "$date: Lane 1: $mph mph\n";
 if ($color eq 'amber' || $color eq 'red') {
  $_[KERNEL]->yield("trigger_zm", $mph, "Lane 1");
 }

 $_[KERNEL]->delay(poll_chan_1 => $polltime);
}

sub calculate_speed_2 {
 my $time = $time4 - $time3;
 my $date = localtime(time);

 my $fps = $distance_2 / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);

 print "$date: Lane 2: $mph mph\n";
 if ($color eq 'amber' || $color eq 'red') {
  $_[KERNEL]->yield("trigger_zm", $mph, "Lane 2");
 }
 $_[KERNEL]->delay(poll_chan_3 => $polltime);
}
