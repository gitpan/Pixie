#!perl -w

##
## Test Pixie's public interface
##

use blib;
use strict;

use Test::More;

use Pixie;

BEGIN {
    unless (Pixie->can( 'fetch' ) and Pixie->can( 'remove' )) {
	plan skip_all => "new interface methods not yet available";
    } else {
	plan 'no_plan';
    }
}

my $pixie = Pixie->new->connect( 'memory' );

## Test named store:
my $foo     = Foo->new;
my $foo_oid = $pixie->store( 'foo' => $foo );
ok( $foo_oid, 'store( foo => $foo )' );
print "foo_oid: $foo_oid\n";

## Test single param store:
my $bar     = Bar->new;
my $bar_oid = $pixie->store( $bar );
ok( $bar_oid, 'store( $obj )' );

## Test backwards compat insert & bind_name:
my $baz = Baz->new;
my $baz_oid = $pixie->insert( $baz );
ok( $baz_oid, 'insert( $baz )' );
ok( $pixie->bind_name( 'baz' => $baz ), 'bind_name( baz => $baz )' );

## Test backwards compat fetch:
isa_ok( $pixie->get( $foo_oid ),           'Foo', 'get( $foo_oid )' );
isa_ok( $pixie->get( $bar_oid ),           'Bar', 'get( $bar_oid )' );
isa_ok( $pixie->get( $baz_oid ),           'Baz', 'get( $baz_oid )' );

## Test backwards compat get_object_named:
isa_ok( $pixie->get_object_named( 'baz' ), 'Baz', 'get_object_named( baz )' );

## Test various forms of fetch:
isa_ok( $pixie->fetch( name => 'foo' ),      'Foo', 'fetch( name => bar )' );
isa_ok( $pixie->fetch( oid => $bar_oid ),    'Bar', 'fetch( oid => $bar_oid )' );
isa_ok( $pixie->fetch( 'foo' ),              'Foo', 'fetch( $name )' );

## Test bind_name of an existing object:
TODO: {
  local $TODO = "implement this";
  my $bar_again = eval {
    $pixie->bind_name( 'bar' => $bar_oid );
    $pixie->fetch( 'bar' );
  };
  isa_ok( $bar_again, ref($bar), 'bind_name( bar => $bar_oid )' );
  diag( "error msg: $@" ) if $@;
}

## Test remove:
ok( eval { $pixie->remove( 'foo' ) }, 'remove( foo )' );
diag($@) if $@;
is( $pixie->fetch( 'foo' ), undef, 'cannot fetch $name anymore' );
is( $pixie->fetch( $foo_oid ),  undef, 'cannot fetch underlying $foo_oid anymore' );

ok( $pixie->remove( $bar_oid ), 'remove( $bar_oid )' );
is( $pixie->fetch( $bar_oid ), undef, 'cannot fetch( $bar_oid )' );

# don't test deleting nested objects here...


package Foo;
sub new { bless {}, shift; }

package Bar;
sub new { bless {}, shift; }

package Baz;
sub new { bless {}, shift; }
