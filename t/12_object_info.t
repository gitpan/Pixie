##
## Pixie::ObjectInfo tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;
use Test::MockObject;
use Scalar::Util qw( isweak );

use MockPixie qw( $pixie $lockstrat );

BEGIN { use_ok( 'Pixie::ObjectInfo' ); }

## new
{
    my $info = Pixie::ObjectInfo->new;
    ok( $info->_oid, 'new creates _oid' );
    is( $info->px_insertion_thaw, $info, 'px_insertion_thaw' );
}

## make_from
{
    my $obj  = Test::MockObject->new->set_always( '_oid', 'test oid' );
    my $info = Pixie::ObjectInfo->make_from( $obj );
    if (isa_ok( $info, 'Pixie::ObjectInfo' )) {
	is( $info->_oid, 'test oid', ' expected _oid' );
	is( $info->the_object, $obj, ' expected object' );
	is( $info->pixie, $pixie,    ' expected pixie' );
    }
}

## _oid
{
    my $info = bless {}, 'Pixie::ObjectInfo';
    ok( $info->_oid,                     '_oid lazy init' );
    is( $info->set__oid( 'foo' ), $info, 'set__oid' );
    is( $info->_oid, 'foo',              '_oid' );
}

## the_object
{
    my $info = Pixie::ObjectInfo->new;
    my $obj  = Test::MockObject->new;
    is( $info->set_the_object( $obj ), $info,  'set_the_object' );
    is( $info->the_object, $obj,               'the_object' );
    ok( isweak( $info->{the_object} ),         'uses weak reference' );
    dies_ok { $info->set_the_object( 'bar' ) } 'cant set_the_object twice';
}

## lock_strategy
{
    my $info = Pixie::ObjectInfo->new;
    is( $info->set_lock_strategy( 'foo' ), $info, 'set_lock_strategy' );
    is( $info->lock_strategy, 'foo',              'lock_strategy' );
}

## pixie
{
    my $info = Pixie::ObjectInfo->new;
    is( $info->pixie_id, undef,            'pixie_id, pixie not set' );
    is( $info->set_pixie( $pixie ), $info, 'set_pixie' );
    is( $info->pixie, $pixie,              'pixie' );
    is( $info->pixie_id, 'pixie oid',      'pixie_id' );
    ok( $pixie->called( '_oid' ), 'oid was called' );
}

## DESTROY
ok( $pixie->called( 'cache_delete' ),   'pixie->cache_delete was called' );
ok( $lockstrat->called( 'on_DESTROY' ), 'lockstrat->on_DESTROY was called' );

