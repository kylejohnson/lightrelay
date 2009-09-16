#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw(time);
use POE;
use IO::Socket;

my $dev = shift;
my $distance_1 = 8.3; # In feet
my $distance_2 = 8.3; # In feet
my $polltime = .032;
my ($time1, $time2, $time3, $time4);
my $limit = 45;

if (!$dev) {
 print "You must specify the path of the device!\n";
 exit;
}

POE::Session->create(
  inline_states => {
    _start          => \&server_start,
    poll_chan_1     => \&poll_chan_1,
    poll_chan_2     => \&poll_chan_2,
    poll_chan_3     => \&poll_chan_3,
    poll_chan_4     => \&poll_chan_4,
    calculate_speed_1 => \&calculate_speed_1,
    calculate_speed_2 => \&calculate_speed_2,
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
close ($sock);
exit;

sub server_start {
 $_[KERNEL]->yield("poll_chan_1");
 $_[KERNEL]->yield("poll_chan_3");
}

sub trigger_zm {
 my $mph = $_[ARG0] . "mph -";
 my $lane = $_[ARG1];
 print $sock "5|on+6|1|Speed||$mph $lane";
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

sub calculate_speed_1 {
 my $time = $time2 - $time1;
 my $date = localtime(time);

 my $fps = $distance_1 / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);

 print "$date\n";
 print "Lane 1:\t $mph mph\n\n";
 $_[KERNEL]->yield("trigger_zm", $mph, "Lane 1");

 $_[KERNEL]->delay(poll_chan_1 => 1);
}

sub calculate_speed_2 {
 my $time = $time4 - $time3;
 my $date = localtime(time);

 my $fps = $distance_2 / $time;
 my $mph = (($fps * 60) * 60) / 5280;
 $mph = sprintf("%.2f", $mph);

 print "$date\n";
 print "Lane 2:\t $mph mph\n\n";
 $_[KERNEL]->yield("trigger_zm", $mph, "Lane 2");

 $_[KERNEL]->delay(poll_chan_3 => 1);
}
