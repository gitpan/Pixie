#!perl -w

package MemTest;

use strict;
use Pixie;
use Test::More;

use lib 't';
use blib;
use Sunnydale;

use base qw/Test::Class/;

use Devel::Peek;
use Scalar::Util qw/isweak/;
use Test::Exception;


sub new {
  my $proto = shift;
  my $self = $proto->SUPER::new;
  $self->{spec} = shift;

  eval {
    $self->new_pixie or die "Can't connect to pixie";
  };
  return if $@;
  return $self;
}

sub new_pixie {
  my $self = shift;
  Pixie->new->connect($self->{spec})
}

sub simple_test : Test(4) {
  my $self = shift;

  my $pixie = $self->new_pixie;
  my $angel = Vampire->new->has_soul(1)
                          ->name('Angel');
  ok isweak $pixie->{_objectmanager}{pixie}, "weak objectmanager";
  my $oid = $pixie->insert($angel);
  ok $angel->px_is_managed;
  undef($pixie);
  ok ! $angel->px_is_managed;
  no strict 'refs';
}


sub hierarchy_test : Test(18) {
  my $self = shift;
  my $pixie = $self->new_pixie;
  my $angel = Vampire->new->has_soul(1)
                          ->name('Angel')
			  ->sire( Vampire->new->name('Darla'));
  ok !$angel->px_is_managed;
  ok my $oid = $pixie->insert($angel);
  ok $angel->px_is_managed;
  ok $angel->sire->px_is_managed;
  undef($pixie);
  # Angel will *stay* managed because Pixie hasn't yet been destroyed,
  # the 'sire' proxy holds a reference to pixie;
  ok !$angel->px_is_managed;
  ok !$angel->sire->px_is_managed;
  is $angel->sire->name, 'Darla';
  undef($angel);
  return "In memory store is not really persistent" if $self->{spec} eq 'memory';
  ok $pixie = $self->new_pixie;
  ok $angel = $pixie->get($oid);
  ok $angel->px_is_managed;
  ok $angel->sire->px_is_managed;
  isa_ok $angel->sire, 'Pixie::Proxy';
  undef($pixie);
  ok $angel->px_is_managed;
  ok $angel->sire->px_is_managed;
  isa_ok $angel->sire, 'Pixie::Proxy';
  is $angel->sire->name, 'Darla';
  ok !$angel->px_is_managed;
  ok !$angel->sire->px_is_managed;
}


sub UNIVERSAL::px_is_managed {
  my $self = shift;
  defined($self->PIXIE::get_info->the_container);
}

package main;

my @testers = grep defined, map MemTest->new($_),
                      qw/memory dbi:mysql:dbname=test bdb:objects.bdb/;
Test::Class->runtests(@testers);
