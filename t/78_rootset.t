#!perl -w

##
## Pixie 'Root Set' tests
##

use lib 't/lib';
use blib;
use strict;

use Test::Class;

use Common;

my @testers = grep defined, map RootTest->new($_), Common->test_stores;
Test::Class->runtests(@testers);


package RootTest;

use strict;

use Test::More;

use Pixie;
use Sunnydale;

use base qw/Test::Class/;

sub Human::best_friend { $_[0]->{best_friend} }

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

  is_deeply [ $p->rootset ], [ $oid ];
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

