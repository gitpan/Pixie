#!perl -w

##
## Pixie Safe Object IDs tests
##

use lib 't/lib';
use blib;
use strict;

use Test::Class;

use Common;

my @testers = grep defined, map SafeOIDTest->new($_), Common->test_stores;
Test::Class->runtests(@testers);


package SafeOIDTest;

use Pixie;
use Test::More;

use base qw/Test::Class/;

sub new {
  my $proto = shift;
  my $self = $proto->SUPER::new;

  $self->{pixie} = Pixie->new->connect(@_);
  return $self;
}

sub set_up : Test(setup => 1) {
  my $self = shift;
  isa_ok($self->{pixie}, 'Pixie') or die "Not a valid pixie";
}

sub basic : Test(6) {
  my $self = shift;
  my $p = $self->{pixie};

  my $easy = SimpleArray->new(1,2,3);
  ok ! $easy->px_is_managed;
  my $oid = $p->insert($easy);
  ok $oid;
  ok $easy->px_is_managed;
  my $easy_copy = bless($easy->px_as_rawstruct, 'SimpleArray');
  undef $easy;
  $easy = $p->get($oid);
  ok $easy->px_is_managed;
  is $easy->PIXIE::oid, $oid;
  is_deeply $easy, $easy_copy;
}

package SimpleArray;

sub new {
  my $proto = shift;
  bless [ @_ ], $proto;
}

sub UNIVERSAL::px_is_managed {
  my $self = shift;
  defined($self->PIXIE::get_info->pixie);
}

