##
## Basic tests of Pixie's public interface
##

use blib;
use strict;
use warnings;

use Pixie;
use Test::More qw( no_plan );

my $pixie = Pixie->new->connect( 'memory' );

#-----------------------------------------------------------------------------
# Backwards compat methods
#-----------------------------------------------------------------------------

# backwards compat insert & bind_name:
my $baz = Baz->new;
my $baz_oid = $pixie->insert( $baz );
ok( $baz_oid, 'insert( $baz )' );
ok( $pixie->bind_name( 'baz' => $baz ), 'bind_name( baz => $baz )' );

# backwards compat get:
isa_ok( $pixie->get( $baz_oid ), 'Baz', 'get( $baz_oid )' );

# backwards compat get_object_named:
isa_ok( $pixie->get_object_named( 'baz' ), 'Baz', 'get_object_named( baz )' );

# backwards compat delete:
ok( eval { $pixie->delete( $baz_oid ) }, 'delete( $baz_oid )' );
diag($@) if $@;

#-----------------------------------------------------------------------------
# New interface methods
#-----------------------------------------------------------------------------

# deploy & friends:
my $px2 = Pixie->deploy( 'memory' );
ok( $px2, 'deploy( mem )' );
TODO: {
local $TODO = 'not yet implemented';
isa_ok( $px2, 'Pixie', 'deploy( mem ) returns new obj' );
can_ok( $pixie, 'is_deployed' );
}

SKIP: {
    skip( "new interface methods not yet available", 10 )
      unless (Pixie->can( 'fetch' ) and Pixie->can( 'remove' ));

# store w/names
my $foo     = Foo->new;
my $foo_oid = $pixie->store( 'foo' => $foo );
ok( $foo_oid, 'store( foo => $foo )' );
print "foo_oid: $foo_oid\n";

# store single param:
my $bar     = Bar->new;
my $bar_oid = $pixie->store( $bar );
ok( $bar_oid, 'store( $obj )' );

## various forms of fetch:
isa_ok( $pixie->fetch( name => 'foo' ),      'Foo', 'fetch( name => bar )' );
isa_ok( $pixie->fetch( oid => $bar_oid ),    'Bar', 'fetch( oid => $bar_oid )' );
isa_ok( $pixie->fetch( 'foo' ),              'Foo', 'fetch( $name )' );

# bind_name of an existing object:
TODO: {
  local $TODO = "implement this";
  my $bar_again = eval {
    $pixie->bind_name( 'bar' => $bar_oid );
    $pixie->fetch( 'bar' );
  };
  isa_ok( $bar_again, ref($bar), 'bind_name( bar => $bar_oid )' );
  diag( "error msg: $@" ) if $@;
}

# remove w/name
ok( eval { $pixie->remove( 'foo' ) }, 'remove( foo )' );
diag($@) if $@;
is( $pixie->fetch( 'foo' ), undef, 'cannot fetch $name anymore' );
is( $pixie->fetch( $foo_oid ),  undef, 'cannot fetch underlying $foo_oid anymore' );

# remove w/oid
ok( $pixie->remove( $bar_oid ), 'remove( $bar_oid )' );
is( $pixie->fetch( $bar_oid ), undef, 'cannot fetch( $bar_oid )' );

# don't test deleting nested objects here...
}

package Foo;
sub new { bless {}, shift; }

package Bar;
sub new { bless {}, shift; }

package Baz;
sub new { bless {}, shift; }
