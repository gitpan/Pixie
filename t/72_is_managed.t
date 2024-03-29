#!perl -w

##
## Pixie 'memory' store tests (but it's for all defined store types)?
##

use lib 't/lib';
use blib;
use strict;

use Test::Class;

use Common;

my @testers = grep defined, map MemTest->new($_), Common->test_stores;
Test::Class->runtests(@testers);


package MemTest;

use strict;

use Pixie;
use Test::More;

use Devel::Peek;
use Scalar::Util qw/isweak/;
use Test::Exception;

use Sunnydale;

use base qw/Test::Class/;

sub new {
  my $proto = shift;
  my $self  = $proto->SUPER::new;
  $self->{spec} = shift;

  eval { $self->new_pixie or die "Can't connect to pixie"; };
  return if $@;

  return $self;
}

sub new_pixie {
  my $self = shift;
  eval { Pixie->deploy($self->{spec})};
  Pixie->new->connect($self->{spec});
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
  my $self  = shift;
  my $pixie = $self->new_pixie;
  my $angel = Vampire->new->has_soul(1)
                          ->name('Angel')
			  ->sire( Vampire->new->name('Darla'));

  ok !$angel->px_is_managed;
  ok my $oid = $pixie->insert($angel);
  ok $angel->px_is_managed;
  ok $angel->sire->px_is_managed;
  undef($pixie);

  ok ! $angel->px_is_managed,       'Angel is no longer managed -- no proxies';
  ok ! $angel->sire->px_is_managed, 'Nor is Darla';
  is $angel->sire->name, 'Darla',   '(sire is Darla)';
  undef($angel);

  return "In memory store is not really persistent" if $self->{spec} eq 'memory';
  # Angel will *stay* managed because Pixie hasn't yet been destroyed,
  # the 'sire' proxy holds a reference to pixie;
  ok $pixie = $self->new_pixie,        'new pixie';
  ok $angel = $pixie->get($oid),       'get stored angel';
  ok $angel->px_is_managed,            'angel is managed';
  ok $angel->sire->px_is_managed,      'angel->sire is managed';
  isa_ok $angel->sire, 'Pixie::Proxy', 'angel->sire';
  undef($pixie);

  ok $angel->px_is_managed,            'Angel stays managed -- proxy extant';
  ok $angel->sire->px_is_managed,      'Darla stays managed (is a proxy)';
  isa_ok $angel->sire, 'Pixie::Proxy', 'angel->sire';
  is $angel->sire->name, 'Darla',      'Deferred fetch still works';
  ok !$angel->px_is_managed,           'Angel no longer managed -- no proxies';
  ok !$angel->sire->px_is_managed,     'Darla no longer managed -- no proxy';
}

sub UNIVERSAL::px_is_managed {
  my $self = shift;
  defined($self->PIXIE::get_info->pixie);
}

1;
