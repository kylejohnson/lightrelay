#!/usr/bin/perl

use warnings;
use strict;
use POE;

$| = 1;

POE::Session->create(
  inline_states => {
    _start         => \&bootstrap,
    event_part_one => \&task_part_one,
    event_part_two => \&task_part_two,
    something_else => \&do_something_else,
  }
);

POE::Kernel->run();
exit;

sub bootstrap {
  $_[HEAP]->{is_running} = 1;
  $_[KERNEL]->yield("event_part_one");
  $_[KERNEL]->yield("something_else");
}

sub task_part_one {
  print "Doing some work here...\n";
  $_[KERNEL]->delay(event_part_two => 1);
}

sub task_part_two {
  print "\nFinishing up now.\n";
  $_[HEAP]->{is_running} = 0;
}

sub do_something_else {
  print ".";
  $_[KERNEL]->yield("something_else") if $_[HEAP]->{is_running};
}
