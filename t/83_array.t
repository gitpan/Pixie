#!perl

##
## Pixie 'array' tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More tests => 3;

use Springfield;

use vars qw/$intrusive/;

my $children = $intrusive ? 'ia_children' : 'children';

BEGIN { use_ok( 'Pixie' ); }

ok my $store = Pixie->new, 'new Pixie';

my %id;
my @kids = qw( Bart Lisa Maggie );

stdpop();

is $SpringfieldObject::pop, 0, 'SprinfieldObject::pop';


sub empty_store {
  $store->clear_storage;
  $store;
}

sub NaturalPerson::children
{
  my ($self) = @_;
  join(' ', map { $_->{firstName} || '' } @{ $self->{$children} } )
}

sub marge_test {
  my $storage = shift;
  ok( $intrusive
      || $storage->get( $id{Marge} )->children eq 'Bart Lisa Maggie' );
}

sub stdpop {
  my $storage = empty_store;

  my @children = map { NaturalPerson->new( firstName => $_ ) } @kids;
  @id { @kids } = map $storage->insert( $_ ), @children;

  my $homer = NaturalPerson->new( firstName => 'Homer',
                                  $children => [ @children ] );
	$id{Homer} = $storage->insert($homer);

	my $marge = NaturalPerson->new( firstName => 'Marge' );
	$marge->{$children} = [ @children ] unless $intrusive;
	$id{Marge} = $storage->insert($marge);
}
