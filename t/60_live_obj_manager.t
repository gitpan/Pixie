##
## Tests for Pixie::LiveObjectManager
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;
use Scalar::Util qw( weaken isweak );

use MockPixie qw( $pixie );

BEGIN { use_ok( 'Pixie::LiveObjectManager' ); }

$pixie->mock( lock_strategy => sub { } );

my $lom = Pixie::LiveObjectManager->new;

isa_ok( $lom->{_live_cache}, 'HASH', '_live_cache' );

## set_pixie
$lom->set_pixie( $pixie );
ok( isweak( $lom->{pixie} ), 'set_pixie' );

## cache: _insert / _get / _delete / _size / _keys
{
    my $obj = bless {}, 'Foo';

    is( $lom->cache_size, 0,           'cache_size' );
    is_deeply( [$lom->cache_keys], [], 'cache_keys' );

    my ($oid, $obj2) = $lom->cache_insert( $obj );
    ok( $oid,        ' cache_insert returns oid' );
    is( $obj2, $obj, ' cache_insert return obj' );

    ok( isweak( $lom->{_live_cache}{$oid} ), 'obj in cache is a weak copy' );
    is( $lom->cache_size, 1, 'cache_size' );

    my @keys = $lom->cache_keys;
    is( $keys[0], $oid, 'cache_keys' );

    my $obj3 = $lom->cache_get( $oid );
    is( $obj3, $obj, 'cache_get' );

    my $obj4 = $lom->cache_delete( $oid );
    isa_ok( $obj4, 'Pixie::ObjectInfo', 'cache_delete' );
    is( $obj4->the_object, $obj,        ' points to obj' );
    is( $lom->cache_get( $oid ), undef, ' cant get from cache anymore' );
}


## get_oid_for / get_info_for / get_info_for_oid
{
    my $obj = bless {}, 'Foo';
    my $oid = $lom->get_oid_for( $obj );
    ok( $oid, 'get_oid_for( obj )' );
    throws_ok
      { $lom->get_oid_for( bless {}, 'Pixie::ObjectInfo' ) }
      qr/can.t get oid for/i,
      'get_oid_for( object info';

    my $info1 = $lom->get_info_for( $obj );
    isa_ok( $info1, 'Pixie::ObjectInfo', 'get_info_for( obj )' );

    $lom->cache_insert( $obj );
    my $info2 = $lom->get_info_for( $oid );
    isa_ok( $info2, 'Pixie::ObjectInfo', 'get_info_for( oid )' );

    $lom->cache_delete( $oid );
    is( $lom->get_info_for( $oid ), undef, 'get_info_for( oid ), not cached' );
}

## bind_object_to_oid
{
    my $obj = bless {}, 'Foo';
    my $oid = 'test oid';

    no warnings;
    local *Pixie::get_the_current_lock_strategy = sub { };
    use warnings;

    my $ret = $lom->bind_object_to_oid( $obj => $oid );
    ok( $ret, 'bind_object_to_oid' );
  TODO: {
	local $TODO = 'return self';
	is( $ret, $lom, ' bind_object_to_oid retval' );
    }

    is( $obj->PIXIE::oid, $oid, ' sets oid' );

    # try overwriting another obj's info:
    $lom->cache_insert( $obj );

    my $obj2 = bless {}, 'Bar';
    $lom->bind_object_to_oid( $obj2 => $oid );
    is( $obj2->PIXIE::oid, $oid, 'bind_object_to_oid, overwrite obj w/same oid' );
  TODO: {
	local $TODO = 'remove info from old object?';
	is( $obj2->PIXIE::get_info->the_object, $obj2, ' points to right obj' );
	isnt( $obj->PIXIE::oid, $oid, ' old object oid reset' );
    }
}

## assert_ownership_of
{
    my $obj = bless {}, 'Foo';

    $pixie->mock( manages_object => sub { 1 } );
    ok( $lom->assert_ownership_of( $obj ), 'assert_ownership_of' );

    $pixie->mock( manages_object => sub { 0 } );
    throws_ok
      { $lom->assert_ownership_of( $obj ) }
      qr/not managed by/,
      'assert_ownership_of (not managed by me)';
}

## lock_object / unlock_object
{
    my $obj = bless {}, 'Foo';

    $pixie->mock( store             => sub { $_[0] } )
          ->mock( manages_object    => sub { 1 } )
          ->mock( lock_object_for   => sub { 'locked' } )
          ->mock( unlock_object_for => sub { 'unlocked' } );
    is( $lom->lock_object( $obj ), 'locked',     'lock_object' );
    is( $lom->unlock_object( $obj ), 'unlocked', 'unlock_object' );

    is( $lom->lock_strategy_for( $obj => 'foo' ), 'foo', 'lock_strategy_for (set)' );
    is( $lom->lock_strategy_for( $obj ), 'foo',          'lock_strategy_for (get)' );
}

## DESTROY
{
    my $obj = bless {}, 'Foo';
    $lom->cache_insert( $obj );
    ok( $obj->PIXIE::get_info, 'object has info before destroy' );

    weaken( $lom ); # call DESTROY
    is( $lom, undef, 'obj manager destroyed when weakened' );
    ok( !$obj->Pixie::Info::px_get_info, 'object has no info after destroy' );
}
