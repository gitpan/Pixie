##
## Pixie::Proxy tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;
use Scalar::Util qw( weaken refaddr );

use MockPixie qw( $pixie );

BEGIN { use_ok( 'Pixie::Proxy' ); }

# CAVEAT:
#  Be wary using Test::MockObject when the DESTROY method calls a mocked method.
#  You'll end up with references to dead objects!

$pixie->set_always( forget_about => 1 );

## px_make_proxy
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    isa_ok( $hv_proxy, 'Pixie::Proxy::HASH', 'px_make_proxy hv' );
    is( $hv_proxy->_oid, 'hv_oid',           ' expected _oid' );
    is( $hv_proxy->px_class, ref($hv_obj),   ' expected px_class' );

    my $av_obj   = bless [qw( a b c )], 'MyArrayObject';
    my $av_proxy = Pixie::Proxy->px_make_proxy( 'av_oid' => $av_obj );
    isa_ok( $av_proxy, 'Pixie::Proxy::ARRAY', 'px_make_proxy av' );
    is( $av_proxy->_oid, 'av_oid',            ' expected _oid' );
    is( $av_proxy->px_class, ref($av_obj),    ' expected px_class' );

  TODO: {
	local $TODO = 'implement scalar proxies';
	lives_ok {
	    my $sv       = 'scalar';
	    my $sv_obj   = bless \$sv, 'MyScalarObject';
	    my $sv_proxy = Pixie::Proxy->px_make_proxy( 'sv_oid' => $sv_obj );
	    isa_ok( $sv_proxy, 'Pixie::Proxy::SCALAR', 'px_make_proxy' );
	    is( $sv_proxy->_oid, 'sv_oid',             ' expected _oid' );
	    is( $sv_proxy->px_class, ref($sv_obj),     ' expected px_class' );
	} 'px_make_proxy sv';
    }
}

## px_fetch_from & px_restore
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored( $hv_proxy, $hv_obj );

    ## px_fetch
    is( $hv_proxy->px_fetch_from( $pixie ), $hv_obj, 'px_fetch_from' );

    ## px_restore
    is( $hv_proxy->px_restore, $hv_proxy, 'px_restore' );
    is_deeply( $hv_proxy, $hv_obj,        ' looks like original obj' );
    isa_ok( $hv_proxy, 'MyHashObject',    ' blessed into right class:' );
}

## isa
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    ok( $hv_proxy->isa( 'Pixie::Object' ), 'proxy->isa Pixie::Object' );
    ok( $hv_proxy->isa( 'MyHashObject' ),  'proxy->isa MyHashObject' );
}

## can
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored( $hv_proxy, $hv_obj );

    local *{ MyHashObject::foo } = sub { 'i can foo' };
    ok( $hv_proxy->can( 'px_restore' ),  'proxy->can px_restore' );
    ok( $hv_proxy->can( 'foo' ),         'proxy->can foo' );
    isa_ok( $hv_proxy, 'MyHashObject',   ' restores proxy on existent method' );
}

TODO: {
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored( $hv_proxy, $hv_obj );

    ok( !$hv_proxy->can( 'non-existent' ), 'proxy->cant non-existent method' );

    local $TODO = 'dont restore obj unless px_class->can( method )';
    isa_ok( $hv_proxy, 'Pixie::Proxy::HASH', ' doesnt restore proxy on non-existent method' );
    $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );

    # avoid Test::MockObject making refs to destroyed objects:
    $hv_proxy->px_the_store(undef);
}

## STORABLE_freeze
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );

    my @ret = $hv_proxy->STORABLE_freeze;
    is_deeply( \@ret, ['hv_oid', ['MyHashObject']], 'STORABLE_freeze' );
    is( $hv_proxy->STORABLE_freeze( 'cloning' ), undef, 'STORABLE_freeze( cloning )' );
}

## STORABLE_thaw
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );

    is( $hv_proxy->STORABLE_thaw( undef, 'hv_oid', ['MyHashObject'] ),
	$hv_proxy,
	'STORABLE_thaw' );
    is( $hv_proxy->_oid, 'hv_oid',           ' sets _oid' );
    is( $hv_proxy->px_class, 'MyHashObject', ' sets px_class' );
    is( $hv_proxy->STORABLE_thaw( 'cloning' ), undef, 'STORABLE_thaw( cloning )' );
}

TODO: {
    local $TODO = 'try STORABLE_freeze & STORABLE_thaw together using Storable';
    ok( 0, 'Storable freeze/thaw' );
}

## _px_insertion_thaw / _px_insertion_freeze
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    my $freeze   = $hv_proxy->_px_insertion_thaw;

    is_deeply( $freeze, $hv_proxy,                '_px_insertion_freeze' );
    is( $hv_proxy->_px_insertion_thaw, $hv_proxy, '_px_insertion_thaw' );
    is( $hv_proxy->px_the_store, $pixie,          ' sets px_the_store' );

    # avoid Test::MockObject making refs to destroyed objects:
    $hv_proxy->px_the_store(undef);
}

## _px_extraction_thaw, case 1: obj not cached
{
    my $cache;
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored_with_cache( $hv_proxy, $hv_obj, \$cache );

    my $ret = $hv_proxy->_px_extraction_thaw;
    is( $ret, $hv_proxy,   '_px_extraction_thaw' );
    is( $cache, $hv_proxy, ' proxy obj added to cache' );

    # avoid Test::MockObject making refs to destroyed objects:
    $hv_proxy->px_the_store(undef);
}

## _px_extraction_thaw, case 2: px_is_immediate
{
    my $cache;
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored_with_cache( $hv_proxy, $hv_obj, \$cache );

    no warnings;
    local *{ MyHashObject::px_is_immediate } = sub { 1 };
    use warnings;
    my $ret = $hv_proxy->_px_extraction_thaw;
    is( $ret, $hv_obj,    '_px_extraction_thaw, px_is_immediate' );
  TODO: {
	local $TODO = 'not yet implemented';
	is( $cache, $hv_obj, ' orig obj added to cache' );
    }
}

## _px_extraction_thaw, case 3: obj is cached
{
    my $cache;
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored_with_cache( $hv_proxy, $hv_obj, \$cache );

    $cache = $hv_obj;
    my $ret = $hv_proxy->_px_extraction_thaw;
    is( $ret, $hv_obj, '_px_extraction_thaw, obj is cached' );
    isa_ok( $hv_proxy, 'Class::Whitehole', ' reblessed proxy' );
}

## AUTOLOAD
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored( $hv_proxy, $hv_obj );
    dies_ok { $hv_proxy->non_existent } 'call non_existent method on proxy';
    isa_ok( $hv_proxy, 'MyHashObject', ' reblessed proxy' );
}

{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    pretend_proxy_obj_is_stored( $hv_proxy, $hv_obj );
    local *{ MyHashObject::foo } = sub { 'foo test' };
    lives_ok
      { is( $hv_proxy->foo, 'foo test', 'proxy->foo' ) }
      'call existing method on proxy';
    isa_ok( $hv_proxy, 'MyHashObject', ' reblessed proxy' );
}

## DESTROY
{
    my $hv_obj   = MyHashObject->new;
    my $hv_proxy = Pixie::Proxy->px_make_proxy( 'hv_oid' => $hv_obj );
    my $px       = Test::MockObject->new->set_always( forget_about => 1 );
    $hv_proxy->px_the_store( $px );
    $hv_proxy->DESTROY;
    ok( $px->called( 'forget_about' ), 'DESTROY calls pixie->forget_about' );
    $px->clear;

    # avoid Test::MockObject making refs to destroyed objects:
    $hv_proxy->px_the_store(undef);
    weaken( $hv_proxy );
    is( $hv_proxy, undef, 'proxy obj is destroyed' );
}



#-----------------------------------------------------------------------------
# Helper subs

sub pretend_proxy_obj_is_stored_with_cache {
    my $proxy     = shift;
    my $obj       = shift;
    my $cache_ref = shift;
    weaken( $cache_ref );
    pretend_proxy_obj_is_stored( $proxy, $obj );
    $pixie->mock( cache_get    => sub { $$cache_ref } )
	  ->mock( cache_insert => sub { $$cache_ref = $_[1] } );
}

sub pretend_proxy_obj_is_stored {
    my $proxy = shift;
    my $obj   = shift;
    weaken( $obj );
    $pixie->mock( _get => sub { $obj } )
          ->mock( get_with_strategy => sub { $obj } )
          ->set_always( get_the_current_lock_strategy => 1 );
    $proxy->px_the_store( $pixie );
}

package MyHashObject;
sub new {
    my $self = bless {}, $_[0];
}
