#!perl -w

package RootTest;

use strict;
use Pixie;
use Test::More;

use lib 't';
use blib;
use Sunnydale;

sub Human::best_friend { $_[0]->{best_friend} }

use base qw/Test::Class/;

sub new {
  my $proto = shift;
  my $self = $proto->SUPER::new;
  my $pixie_spec = shift;
  eval {$self->{pixie} = Pixie->new->connect($pixie_spec)
	or die "Can't connect to pixie";};
  return if $@;
  return $self;
}

sub set_up : Test(setup) {
  my $self = shift;
  $self->{pixie}->clear_storage;
  return $self;
}

sub leak_test : Test(teardown => 2) {
  my $self = shift;
  Sunnydale::leaktest;
  is $self->{pixie}->cache_size, 0, "Cache Leak";
}

sub simple : Test(2) {
  my $self = shift;
  my $p = $self->{pixie};

  my $oid = $p->insert(Human->new(name => 'Buffy'));

  is_deeply [ $p->rootset ], [ $oid ] or die;
  $p->delete($oid);
  is_deeply [ $p->rootset ], [];
}

sub naming : Test {
  my $self = shift;
  my $p = $self->{pixie};

  $p->bind_name('The Slayer' => Human->new(name => 'Buffy'));

  my @rootset = $p->rootset;
  is scalar(@rootset), 1;
}

package main;

my @specs = 'memory';
push @specs, 'bdb:objects.bdb' if $ENV{DEVELOPER_TESTS};
push @specs, split / +/, $ENV{PIXIE_TEST_STORES} if $ENV{PIXIE_TEST_STORES};

my @testers = grep defined, map RootTest->new($_), @specs;

Test::Class->runtests(@testers);
