#!perl -w 

package WorkingSetTest;

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
  $self->{pixie_spec} = shift;
  return $self;
}

sub set_up : Test(setup) {
  my $self = shift;
  $self->connect->clear_storage;
  return $self;
}

sub leak_test : Test(teardown => 1) {
  my $self = shift;
  Sunnydale::leaktest;
}


sub connect {
  my $self = shift;
  my $pixie_spec = $self->{pixie_spec};
  Pixie->new->connect($pixie_spec)
}

sub simple : Test(tests => 6) {
  my $self = shift;
  my $p = $self->connect;
  my %oid;

  my $buffy = Human->new(name => 'Buffy');
  my $willow = Human->new(name => 'Willow');

  $buffy->{best_friend} = $willow;
  $oid{Buffy} = $p->insert($buffy);
  $oid{Willow} = $willow->PIXIE::oid;
  undef $_ for $buffy, $willow;

  is_deeply [$p->neighbours($oid{Buffy})], [$oid{Willow}];
  is_deeply [$p->rootset], [$oid{Buffy}];
  is_deeply [ sort $p->live_set ], [ sort values %oid ];

  undef($p);
  $p = $self->connect;

  is_deeply [$p->neighbours($oid{Buffy})], [$oid{Willow}];
  is_deeply [$p->rootset], [$oid{Buffy}];
  is_deeply [ sort $p->live_set ], [ sort values %oid ];
}

sub cycle : Test(6) {
  my $self = shift;
  my $p = $self->connect;

  my $buffy = Human->new(name => 'Buffy');
  my $willow = Human->new(name => 'Willow');
  $willow->{best_friend} = $buffy;
  $buffy->{best_friend} = $willow;

  my %oid;
  $oid{Willow} = $p->insert($willow);
  $oid{Buffy} = $buffy->PIXIE::oid;

  for ($buffy, $willow) {
    delete $_->{best_friend};
    undef $_;
  }

  is_deeply [ $p->neighbours($oid{Willow}) ], [ $oid{Buffy} ];
  is_deeply [ $p->rootset ],                  [ $oid{Willow} ];
  is_deeply [ sort $p->live_set ],         [ sort values %oid ];

  undef $p;
  $p = $self->connect;
  is_deeply [ $p->neighbours($oid{Willow}) ], [ $oid{Buffy} ];
  is_deeply [ $p->rootset ],                  [ $oid{Willow} ];
  is_deeply [ sort $p->live_set ],         [ sort values %oid ];
}

sub shared :Test(4) {
  my $self = shift;
  my $p = $self->connect;
  my %oid;

  my $faith = Human->new(name => 'Faith');
  my $cordy = Human->new(name => 'Cordelia');
  my $xander = Human->new(name => 'Xander');

  push @{$faith->{lovers}}, $xander;
  push @{$cordy->{lovers}}, $xander;

  $p->insert($faith);
  $p->insert($cordy);

  for ($faith, $cordy, $xander) {
    $oid{$_->name} = $_->PIXIE::oid;
    undef($_);
  }

  undef $p;
  $p = $self->connect;

  is_deeply [ $p->neighbours($oid{Faith}) ],    [ $oid{Xander} ];
  is_deeply [ $p->neighbours($oid{Cordelia}) ], [ $oid{Xander} ];

  is_deeply [ sort $p->rootset ],               [ sort @oid{qw/Cordelia Faith/} ];
  is_deeply [ sort $p->live_set ],              [ sort values %oid ];
}

sub working_set_v_live_set : Test(7) {
  my $self = shift;
  my $p = $self->connect;
  my %oid;

  is_deeply [ $p->working_set ], [] or die "Working set not empty";

  my $buffy = Human->new(name => 'Buffy',
			 best_friend => Human->new(name => 'Willow'));
  $p->insert($buffy);

  for ($buffy, $buffy->best_friend) {
    $oid{$_->name} = $_->PIXIE::oid;
    undef($_);
  }

  is_deeply [ $p->rootset ],          [ $oid{Buffy} ];
  is_deeply [ sort $p->live_set ],    [ sort values %oid ];
  is_deeply [ sort $p->working_set ], [ sort values %oid ];

  $p->delete($oid{Buffy});

  is_deeply [ $p->rootset ],          [ ];
  is_deeply [ sort $p->live_set ],    [ ];
  is_deeply [ sort $p->working_set ], [ $oid{Willow} ];
}

package main;

my @specs;
push @specs, 'bdb:objects.bdb';
push @specs, split / +/, $ENV{PIXIE_TEST_STORES} if $ENV{PIXIE_TEST_STORES};

my @testers = grep defined, map WorkingSetTest->new($_), @specs;

Test::Class->runtests(@testers);
