##
## Common tests for Pixie Stores
##

package StoreTests;

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::MockObject;

use MockPixie qw( $pixie );
use Pixie::LockStrat::Exclusive;

use base qw( Pixie::Object );
use accessors qw( dsn store lockstrat store_class );

sub run_tests {
    my $self = shift;
    $self->test_deploy
         ->test_connect
	 ->test_store_get_del
	 ->test_clear
	 ->test_rootset
	 ->test_locking;
}

sub constructor_store_class {
    my $self = shift;
    return 'Pixie::Store::DBI::Default' if $self->store_class =~ /^Pixie::Store::DBI/;
    $self->store_class;
}

## deploy
sub test_deploy {
    my $self = shift;

    my $store = $self->constructor_store_class->deploy( $self->dsn );
    isa_ok( $store, $self->store_class, 'deploy' );

    return $self;
}

## connect
sub test_connect {
    my $self = shift;

    my $store = $self->constructor_store_class->connect( $self->dsn );
    isa_ok( $store, $self->store_class, 'connect' );

    my $lockstrat = Pixie::LockStrat::Exclusive->new;
    $pixie->mock( store => sub { $store } );

    $self->store( $store)
         ->lockstrat( $lockstrat );
}

## store_at / get_object_at / delete
sub test_store_get_del {
    my $self  = shift;
    my $store = $self->store;

    my $obj = bless {}, 'Foo';
    is( $store->store_at( my_oid => $obj, $self->lockstrat ), $obj, 'store_at' );
    is_deeply( $store->get_object_at( 'my_oid' ), $obj, 'get_object_at' );
    ok( $store->_delete( 'my_oid' ),                    '_delete' );
    is( $store->get_object_at( 'my_oid' ), undef,       'cant get_object_at anymore' );
    ok(!$store->_delete( 'my_oid' ),                    'cant _delete non-existent' );

    return $self;
}

## clear
sub test_clear {
    my $self  = shift;
    my $store = $self->store;

    my $obj = bless {}, 'Foo';
    $store->store_at( my_oid => $obj, $self->lockstrat );
    is( $store->clear, $store, 'clear' );
    is( $store->get_object_at( 'my_oid' ), undef, 'actually clears' );

    return $self;
}

## rootset / _add_to_rootset / remove_from_rootset
sub test_rootset {
    my $self  = shift;
    my $store = $self->store;

    my $obj = bless {}, 'Foo';
    $obj->PIXIE::set_oid( 'my_oid' );

    my @rootset = $store->rootset;
    is_deeply( \@rootset, [], 'rootset (empty)' );

    $store->store_at( my_oid => $obj, $self->lockstrat );
    @rootset = $store->rootset;
    is_deeply( \@rootset, [], 'rootset (still empty)' );

    is( $store->_add_to_rootset( $obj ), $store, '_add_to_rootset' );
    @rootset = $store->rootset;
    is_deeply( \@rootset, ['my_oid'], 'rootset (not empty)' );

    is( $store->remove_from_rootset( 'my_oid' ), $store, 'remove_from_rootset' );
    @rootset = $store->rootset;
    is_deeply( \@rootset, [], 'rootset (empty again)' );

    TODO: {
	  local $TODO = 'update _add_to_rootset to accept oids ';
	  lives_ok {
	      is( $store->_add_to_rootset( 'foo_oid' ), $store,
	      '_add_to_rootset( explicit oid )' );
	  } '_add_to_rootset( explicit oid )';
      }

    return $self;
}

## lock / unlock / rollback
sub test_locking {
    my $self  = shift;
    my $store = $self->store;

    is( $store->lock, $store,     'lock (no-op)' );
    is( $store->unlock, $store,   'unlock (no-op)' );
    is( $store->rollback, $store, 'rollback (no-op)' );

    my $oid = 'test oid';
    my $px1 = Test::MockObject->new->set_always( _oid => 'px1' );
    ok( $store->lock_object_for( $oid, $px1 ),   'lock_object_for px1' );
    ok( $store->unlock_object_for( $oid, $px1 ), 'unlock_object_for px1' );

    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->lockstrat->{on_DESTROY_called} = 1; # avoid warning
    %$self = ();
}

1;
