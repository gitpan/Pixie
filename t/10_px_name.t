##
## Pixie::Name tests
##

use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::MockObject;

BEGIN { use_ok( 'Pixie::Name' ); }

my $nm = Pixie::Name->new;

## accessors
is( $nm->_oid( 'oid' ), $nm,      '_oid( set )' );
is( $nm->_oid, 'oid',             '_oid( get )' );
is( $nm->px_target( 'tgt' ), $nm, 'px_target( set )' );
is( $nm->px_target, 'tgt',        'px_target( get )' );

## oid_for_name
is( Pixie::Name->oid_for_name( 'test_name' ), '<NAME:test_name>', 'oid_for_name' );

##
## We've gotta jump through so many hoops to mimick Pixie here, it might make more
## sense to move most of this funtionality into Pixie and keep Pixie::Name a simple
## class with a few accessors and methods for constructing names.
##
## Otherwise we should do these tests after we've tested Pixie itself.
##

## name_object_in
{
    my $pixie = Test::MockObject->new
      ->mock( 'insert',
	      sub {
		  my ($self, $name) = @_;
		  if (isa_ok( $name, 'Pixie::Name', 'name_object_in: pixie->insert' )) {
		      is( $name->_oid, '<NAME:test name>',    '  expected oid' );
		      is_deeply( $name->px_target, [ 1,2,3 ], '  expected target' );
		  }
	      } );
    Pixie::Name->name_object_in( 'test name', [ 1,2,3 ], $pixie );
    ok( $pixie->called( 'insert' ), '  pixie->insert was called' );
}

## get_object_from
{
    my @objs  = ( Test::MockObject->new->set_always( 'px_restore', 'object1' ),
		  Test::MockObject->new->mock( 'px_restore', sub { die 'px_restore' } ));
    my $name  = Pixie::Name->new->_oid( '<NAME:get_objs>' )->px_target([ @objs ]);
    my $pixie = Test::MockObject->new
      ->mock( 'get',
	      sub {
		  my ($self, $oid) = @_;
		  print "pixie->get( $oid )\n";
		  return $name if ($oid eq '<NAME:get_objs>');
	      } )
      ->mock( 'get_with_strategy',
	      sub {
		  my ($self, $oid, $strat) = @_;
		  is( $strat, 'strat', 'get_object_from_with_strategy: passes strategy' );
		  return $self->get( $oid );
	      } );
    my $r1 = Pixie::Name->get_object_from( 'get_objs', $pixie );
    is( $r1, $objs[-1],         '(scalar) get_object_from' );
    ok( $pixie->called( 'get' ),'  pixie->get was called' );
    my @r1 = Pixie::Name->get_object_from( 'get_objs', $pixie );
    is_deeply( \@r1, [ 'object1', $objs[1] ], '(list)   get_object_from' );

    my $r2 = Pixie::Name->get_object_from_with_strategy( 'get_objs', $pixie, 'strat' );
    is( $r2, $objs[-1],         '(scalar) get_object_from_with_strategy' );
    ok( $pixie->called( 'get_with_strategy' ), '  pixie->get_with_strategy was called' );
    my @r2 = Pixie::Name->get_object_from_with_strategy( 'get_objs', $pixie, 'strat' );
    is_deeply( \@r2, [ 'object1', $objs[1] ], '(list)   get_object_from_with_strategy' );
}

## remove_name_from
{
    my $pixie = Test::MockObject->new
      ->mock( 'delete',
	      sub {
		  my ($self, $oid) = @_;
		  is( $oid, '<NAME:del_oid>', 'remove_name_from: expected oid' );
	      } );
    Pixie::Name->remove_name_from( 'del_oid', $pixie );
    ok( $pixie->called( 'delete' ), '  pixie->delete was called' );
}

