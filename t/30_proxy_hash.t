##
## Pixie::Proxy::HASH tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;

BEGIN { local $TODO = 'separate embedded subclasses';
	use_ok( 'Pixie::Proxy::HASH' ); }
BEGIN { use_ok( 'Pixie::Proxy' ); }

my $proxy = Pixie::Proxy::HASH->new;

## _oid & px_oid
is( $proxy->_oid( 'foo' ), $proxy, '_oid set' );
is( $proxy->_oid, 'foo',           '_oid get' );
is( $proxy->px_oid, 'foo',         'px_oid get' );

## px_class
is( $proxy->px_class( 'MyHashObject' ), $proxy, 'px_class set' );
is( $proxy->px_class, 'MyHashObject',           'px_class get' );
dies_ok { Pixie::Proxy::HASH->px_class }        'px_class get as class method';

## px_the_store & px_clear_the_store
is( $proxy->px_the_store( 'store' ), $proxy, 'px_the_store set' );
is( $proxy->px_the_store, 'store',           'px_the_store get' );
TODO: {
    local $TODO = 'should return self';
    is( $proxy->px_clear_the_store, $proxy,  'px_clear_the_store' );
}
is( $proxy->px_the_store, undef,             ' store is cleared' );

## px_lock_strategy
is( $proxy->px_lock_strategy( 'l1' ), $proxy, 'px_lock_strategy set' );
is( $proxy->px_lock_strategy, 'l1',           'px_lock_strategy get' );

## populate_from
{
    my $proxy2 = Pixie::Proxy::HASH->new;
    my $hash   = { class => 'my class' };
    $proxy2->{foo} = 'bar';
    is( $proxy2->populate_from( $hash ), $proxy2, 'populate_from' );
    is( $proxy2->{foo}, undef,                    ' deletes old elems' );
    is( $proxy2->{class}, 'my class',             ' copies elems' );
}

