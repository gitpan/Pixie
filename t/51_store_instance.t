##
## Pixie::Store instance method tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;

use MockPixie qw( $pixie );

BEGIN {
    use_ok( 'Pixie::Store' );
    use MyTestStore;
}

my $store = MyTestStore->new;

## as_string
$store->{spec} = 'test:mytest:dbname=test';
is( $store->as_string, 'MyTestStore: test:mytest:dbname=test', 'as_string' );

## accessors
TODO: {
    local $TODO = '$store->{spec} should be an accessor called $store->dsn';
    can_ok( $store, 'dsn', 'dsn ($store->{spec})' );
}

## abstract methods
dies_ok { $store->deploy }              'deploy';
dies_ok { $store->connect }             'connect';
dies_ok { $store->clear }               'clear';
dies_ok { $store->store_at }            'store_at';
dies_ok { $store->get_object_at }       'get_object_at';
dies_ok { $store->delete }              'delete';
dies_ok { $store->remove }              'remove';
dies_ok { $store->rootset }             'rootset';
dies_ok { $store->_add_to_rootset }     '_add_to_rootset';
dies_ok { $store->remove_from_rootset } 'remove_from_rootset';
dies_ok { $store->lock }                'lock';
dies_ok { $store->unlock }              'unlock';
dies_ok { $store->rollback }            'rollback';

## object_graph_for
{
    can_ok( 'Pixie::ObjectGraph' => 'new' );

    my $cache = {};
    $pixie->mock( bind_name => sub { $cache->{$_[1]} = $_[2] } )
          ->mock( get_object_named => sub { $cache->{$_[1]} } );
    my $graph = $store->object_graph_for( $pixie );
    isa_ok( $graph, 'Pixie::ObjectGraph', 'object_graph_for' );
    ok( keys %$cache, 'graph is added to cache' );
}

## remove_from_store
{
    my $called = '';
    no warnings;
    local *{MyTestStore::remove_from_rootset} = sub {
	my ($self, $oid) = @_;
	is( $called, '',     'remove_from_rootset called' );
	is( $oid, 'my oid', ' expected oid' );
	$called .= 'remove';
	$self;
    };
    local *{MyTestStore::_delete} = sub {
	my ($self, $oid) = @_;
	is( $called, 'remove', '_delet called' );
	is( $oid,    'my oid', ' expected oid' );
	$called .= '_delete';
	$self;
    };
    use warnings;
    is( $store->remove_from_store( 'my oid' ), $store, 'remove_from_store' );
}

## locked_set
isa_ok( $store->locked_set, 'HASH', 'locked_set' );

## lock_object_for / unlock_object_for
{
    my $px2    = Test::MockObject->new->set_always( _oid => 'px2' );
    my $oid    = 'my oid';
    my $px_oid = $pixie->_oid;
    ok( $store->lock_object_for( $oid, $pixie ), 'lock_object_for pixie' );
    is( $store->locked_set->{ $oid }, $px_oid,   '  oid is locked by pixie' );
    is( $store->unlock_object_for( $oid, $pixie ), $px_oid, 'unlock_object_for pixie' );
    ok(!$store->locked_set->{ $oid },            '  oid no longer locked' );

  TODO: {
       local $TODO = 'lock_object_for px2 should fail';
       $store->lock_object_for( $oid, $pixie );
       dies_ok
	 {
	     ok( !$store->lock_object_for( $oid, $px2 ), 'lock_object_for px2 fails' );
	     $store->unlock_object_for( $oid, $px2 )
	 }
	 'lock_object_for px2 fails';
       $store->unlock_object_for( $oid, $pixie )
    }
}

## release_all_locks
{
    $store->lock_object_for( 'a', $pixie );
    $store->lock_object_for( 'b', $pixie );
    my $lset = $store->locked_set;
    ok( $lset->{a} && $lset->{b}, 'locked a & b' );
    is( $store->release_all_locks, $store, 'release_all_locks' );
    ok( ! keys %$lset, 'a & b no longer locked' );
}

## lock_for_GC / unlock_for_GC
{
    no warnings;
    local *{ MyTestStore::lock }   = sub { ok( 1, 'lock_for_GC'     ) };
    local *{ MyTestStore::unlock } = sub { ok( 1, 'unlock_after_GC' ) };
    use warnings;
    $store->lock_for_GC;
    $store->unlock_after_GC;
}

## is_hidden / add_to_rootset
{
    my $hidden = bless {}, 'Foo';
    my $obj    = bless {}, 'Foo';
    require Pixie::Name;
    $hidden->PIXIE::set_oid( Pixie::Name->oid_for_name( 'PIXIE::foo' ) );
    ok( $store->is_hidden( $hidden ), 'is_hidden - yes' );
    ok(!$store->is_hidden( $obj ), 'is_hidden - no' );

    # _add_to_rootset should still be abstract, so will die if called:
    lives_ok
      { $store->add_to_rootset( $hidden ) }
      'add_to_rootset( hidden ) doesnt add';

    local *{ MyTestStore::_add_to_rootset } = sub {
	is( $_[1], $obj, 'add_to_rootset( regular ) adds' )
    };
    $store->add_to_rootset( $obj );
}

## DESTROY
{
    my $store2 = MyTestStore->new;
    $store2->lock_object_for( 'a', $pixie );
    my $lset = $store2->locked_set;
    $store2  = undef;
    ok( ! keys %$lset, 'DESTROY releases locks' );
}

__END__
