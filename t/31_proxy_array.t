##
## Pixie::Proxy::ARRAY tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;

BEGIN { local $TODO = 'separate embedded subclasses';
	use_ok( 'Pixie::Proxy::ARRAY' ); }
BEGIN { use_ok( 'Pixie::Proxy' ); }

my $proxy = Pixie::Proxy::ARRAY->new;

## _oid & px_oid
is( $proxy->_oid( 'foo' ), $proxy, '_oid set' );
is( $proxy->_oid, 'foo',           '_oid get' );
TODO: {
    local $TODO = 'not yet written';
    lives_ok { is( $proxy->px_oid, 'foo', 'px_oid get' ) } 'px_oid get lives';
}

## px_class
is( $proxy->px_class( 'MyArrayObject' ), $proxy, 'px_class set' );
is( $proxy->px_class, 'MyArrayObject',           'px_class get' );
dies_ok { Pixie::Proxy::ARRAY->px_class }        'px_class get as class method';

## px_the_store & px_clear_the_store
is( $proxy->px_the_store( 'store' ), $proxy, 'px_the_store set' );
is( $proxy->px_the_store, 'store',           'px_the_store get' );
is( $proxy->px_clear_the_store, $proxy,      'px_clear_the_store' );
is( $proxy->px_the_store, undef,             ' store is cleared' );

## px_lock_strategy
is( $proxy->px_lock_strategy( 'l1' ), $proxy, 'px_lock_strategy set' );
is( $proxy->px_lock_strategy, 'l1',           'px_lock_strategy get' );

## populate_from
{
    my $proxy2 = Pixie::Proxy::ARRAY->new;
    my $array  = [ qw( foo bar baz ) ];
    $proxy2->[9] = 'nine';
    is( $proxy2->populate_from( $array ), $proxy2, 'populate_from' );
    is( $proxy2->[9], undef,                       ' deletes old elems' );
    is( $proxy2->[0], 'foo',                       ' copies elems' );
    $proxy2->px_clear_the_store; # avoid warnings on DESTROY
}

