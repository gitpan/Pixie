##
## Tests for Pixie (no top-level API tests here)
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;
use Test::MockObject;

BEGIN { use_ok( 'Pixie' ); }

my $pixie = Pixie->new;

## init
isa_ok( $pixie->store, 'Pixie::Store::Memory', 'init connects to memory' );

## as_string
like( $pixie->as_string, qr/^Pixie: .+Pixie::Store::Memory/s, 'as_string' );

## get_the_current...
is( $pixie->get_the_current_pixie, undef,         'get_the_current_pixie' );
is( $pixie->get_the_current_oid,   undef,         'get_the_current_oid' );
is( $pixie->get_the_current_lock_strategy, undef, 'get_the_current_lock_strategy' );
is( $pixie->get_the_current_object_graph, undef,  'get_the_current_object_graph' );

## _oid
ok( $pixie->_oid, '_oid' );

## clear_store
ok( $pixie->clear_store, 'clear_store' );
ok( ! $pixie->store,     ' store deleted' );

$pixie = Pixie->new;

## clear_storage
{
    # can't use Test::MockObject here
    $pixie->store->store_at( 'test oid' => bless {}, 'Foo' );
    $pixie->clear_storage;
    ok( ! $pixie->store->get_object_at( 'test oid' ), 'clear_storage' );
}

## lock_strategy / lock_strategy_for
{
    # lock_strategy
    my $lockstrat = $pixie->lock_strategy;
    isa_ok( $lockstrat, 'Pixie::LockStrat::Null', 'lock_strategy, lazy init' );
    is( $pixie->lock_strategy( 'foo' ), $pixie,   'lock_strategy, set' );
    is( $pixie->lock_strategy, 'foo',             'lock_strategy, get' );

    # lock_strategy_for
    $pixie->{_objectmanager} = Test::MockObject->new
      ->set_always( lock_strategy_for => 'foo' );
    is( $pixie->lock_strategy_for( 'oid' ), 'foo',         'lock_strategy_for (get)' );
    is( $pixie->lock_strategy_for( 'oid', 'set' ), $pixie, 'lock_strategy_for (set)' );

    $lockstrat->{on_DESTROY_called} = 1; # avoid warnings
}

## store_individual / store_individual_at
{
    $pixie  = Pixie->new->lock_strategy( Pixie::LockStrat::Null->new );
    my $obj = bless {}, 'Foo';
    $obj->PIXIE::set_oid( 'my_oid' );

    # this calls both methods:
    my $proxy = $pixie->store_individual( $obj );
    isa_ok( $proxy, 'Pixie::Proxy::HASH',         'store_individual' );
    ok( $pixie->store->get_object_at( 'my_oid' ), ' obj found in store' );

    throws_ok
      { $pixie->store_individual( Pixie::ObjectInfo->new ) }
      qr/can.t store a/i,
      'store_individual px object info';

    $pixie->lock_strategy->{on_DESTROY_called} = 1; # avoid warnings
}

## proxied_content / proxy_finder
{
    my $pixie  = Pixie->new;
    my $obj    = bless { bar => 'baz' }, 'Bar';
    $obj->PIXIE::set_oid( 'bar_oid' );
    my $proxy  = Pixie::Proxy->px_make_proxy( bar_oid => $obj );

    local %Pixie::neighbours;
    is( Pixie::proxy_finder( $proxy ), $proxy, 'proxy_finder' );
    ok( $Pixie::neighbours{bar_oid},           ' finds proxies' );

    my $holder = bless({ oid     => 'my oid',
			 class   => 'Foo',
			 content => { foo => $proxy } },
		       'Pixie::ObjHolder' );
    my @neighbours = $pixie->proxied_content( $holder );
    is_deeply( \@neighbours, [ 'bar_oid' ], 'proxied_content' );
}

## insertion_freeze / insertion_thaw
{
    my $pixie   = Pixie->new;
    my $manager = $pixie->{_objectmanager};
    my $obj     = bless { foo => 1 }, 'Foo';
    my $holder  = $pixie->insertion_freeze( $obj );

    # freeze
    isa_ok( $holder, 'Pixie::ObjHolder', 'insertion_freeze' );
    ok( $holder->{oid},                  ' holder->oid' );
    is( $holder->{class}, 'Foo',         ' holder->class' );
    is_deeply( $holder->{content}, $obj, ' holder->content' );
    ok( $manager->cache_get( $holder->{oid} ),
	' object is cached in object manager' );

    my $info = $manager->get_info_for_oid( $holder->{oid} );
    ok( $info, ' cached obj has info' );

    # thaw
    my $obj2  = bless { bar => 1 }, 'Bar';
    my $proxy = Pixie::Proxy->px_make_proxy( bar_oid => $obj2 );
    my $graph = Pixie::ObjectGraph->new;

    no warnings;
    local *Pixie::get_the_current_object_graph = sub { $graph };
    use warnings;

    $holder->{content}->{bar} = $proxy;

    my $proxy1 = $pixie->insertion_thaw( $holder );
    isa_ok( $proxy1, 'Pixie::Proxy::HASH',     'insertion_thaw' );
    is( $proxy1->_oid, $holder->{oid},         ' proxy has right oid' );
    is( $info->the_object, $obj,               ' object info has right obj' );
    my @neighbours = $graph->neighbours( $holder->{oid} );
    is_deeply( \@neighbours, ['bar_oid'],      ' object graph is populated' );
}

## do_dump_and_eval
{
    $pixie  = Pixie->new;
    my $obj = bless { foo => 1, bar => bless ['eek'], 'Bar' };

    no warnings;
    local *Pixie::lock_store = sub { 1 };
    local *Pixie::lock_store = sub { 1 };
    use warnings;

    my $copy = $pixie->do_dump_and_eval( $obj );
    is_deeply( $copy, $obj, 'do_dump_and_eval' );
    isnt( $copy, $obj, ' creates a deep copy' );
}

## _insert


## insert (tested in api tests)

## get (tested in api tests)
## get_with_strategy
## bail_out
## delete (tested in api tests)
## forget_about

## make_new_object
{
    my $pixie = Pixie->new;
    my $obj   = bless { foo => 'bar' }, 'Foo';
    local *Foo::new = sub { bless {}, $_[0] };

    my $obj2 = $pixie->make_new_object( $obj, 'Foo' );
    isa_ok( $obj2, 'Foo',   'make_new_object' );
    isnt( $obj2, $obj,      ' obj is a copy' );
    is_deeply( $obj2, $obj, ' obj is same as original' );
}

## extraction_freeze / extraction_thaw
{
    my $pixie = Pixie->new;
    my $obj   = bless { foo => 'bar' }, 'Foo';
    is( $pixie->extraction_freeze( $obj ), $obj, 'extraction_freeze' );

    local *Foo::new = sub { bless {}, $_[0] };
    local $Pixie::the_current_oid   = 'foo_oid';
    local $Pixie::the_current_pixie = $pixie;

    my $obj2 = $pixie->extraction_thaw( $obj );
    isa_ok( $obj2, 'Foo',             'extraction_thaw' );
    isnt( $obj2, $obj,                ' obj is a copy' );
    is_deeply( $obj2, $obj,           ' obj is same as original' );
    is( $obj2->PIXIE::oid, 'foo_oid', ' obj has right oid' );
    isa_ok( $obj, 'Class::Whitehole', ' original obj' );
}

## _get

## manages_object
{
    my $pixie = Pixie->new;
    my $obj   = bless {}, 'Foo';
    ok( ! $pixie->manages_object( $obj ), 'manages_object, not managed' );
    $pixie->insert( $obj );
    ok( $pixie->manages_object( $obj ), 'manages_object' );
}

## Caching methods
{
    # These should be tested in Pixie::LiveObjectManager tests:
    my $pixie       = Pixie->new;
    my $obj_manager = Test::MockObject->new
      ->set_always( cache_insert => 'ins' )
      ->set_always( cache_get    => 'get' )
      ->set_always( cache_delete => 'del' )
      ->set_always( cache_size   => 'size' )
      ->set_always( cache_keys   => 'keys' );
    $pixie->{_objectmanager} = $obj_manager;
    is( $pixie->cache_insert, 'ins',      'cache_insert' );
    is( $pixie->cache_get, 'get',         'cache_get' );
    is( $pixie->cache_delete, 'del',      'cache_delete' );
    is( $pixie->cache_size, 'size',       'cache_size' );
    is( $pixie->get_cached_keys, 'keys',  'get_cached_keys' );
}

## Naming methods
{
    # These should be tested in Pixie::Name tests:
    my $pixie = Pixie->new;

    no warnings;
    local *Pixie::Name::name_object_in   = sub { 'name_in' };
    local *Pixie::Name::remove_name_from = sub { 'remove' };
    local *Pixie::Name::get_object_from  = sub { 'get' };
    use warnings;

    is( $pixie->bind_name, 'name_in',    'bind_name' );
    is( $pixie->unbind_name, 'remove',   'unbind_name' );
    is( $pixie->get_object_named, 'get', 'get_object_named' );
}

## rootset
## add_to_rootset
## neighbours
## run_GC
## live_set
## object_graph
## working_set
## ensure_storability

## Locking methods
{
    # These should be tested in Pixie::Store tests:
    my $pixie = Pixie->new;
    my $store = Test::MockObject->new
      ->set_always( lock     => 'slock' )
      ->set_always( unlock   => 'sunlock' )
      ->set_always( rollback => 'srollback' )
      ->set_always( release_all_locks => 1 );
    $pixie->store( $store );
    is( $pixie->lock_store, 'slock',         'lock_store' );
    is( $pixie->unlock_store, 'sunlock',     'unlock_store' );
    is( $pixie->rollback_store, 'srollback', 'rollback_store' );

    # These should be tested in Pixie::LiveObjectManager:
    my $obj_manager = Test::MockObject->new
      ->set_always( lock_object   => 'lock' )
      ->set_always( unlock_object => 'unlock' );
    $pixie->{_objectmanager} = $obj_manager;
    is( $pixie->lock_object, 'lock',     'lock_object' );
    is( $pixie->unlock_object, 'unlock', 'unlock_object' );
}

## DESTROY

## px_freeze
## _px_extraction_thaw
