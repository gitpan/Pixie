##
## Tests for Mysql-based Pixie Stores
##

package StoreTests::Mysql;

use Test::More;
use Test::Exception;

use base qw( StoreTests::DBI );

# some sensible lock timeouts, otherwise we'll end up waiting forever...
$Pixie::Store::DBI::Mysql::LOCK_TIMEOUT    = 1;
$Pixie::Store::DBI::Mysql::GC_LOCK_TIMEOUT = 5;

sub test_lock_unlock {
    my $self  = shift;
    my $store = $self->store;
    my $dbh   = $self->new_dbh;
    my $lock;

    is( $store->lock, $store, 'lock' );
    $lock = $dbh->selectrow_arrayref( qq{SELECT GET_LOCK('pixie', 0)} )->[0];
    ok( !$lock, '"pixie" is locked' );

    is( $store->unlock, $store, 'unlock' );
    $lock = $dbh->selectrow_arrayref( qq{SELECT GET_LOCK('pixie', 0)} )->[0];
    $dbh->do(q{SELECT RELEASE_LOCK('pixie')});
    ok( $lock, '"pixie" isnt locked' );

    return $self;
}

sub test_rollback {
    my $self  = shift;
    my $store = $self->store;
    my $dbh   = $self->new_dbh;

  TODO: {
	local $TODO = 'use INNODB & TRANSACTIONS for mysql locking?';
	$store->lock;
	lives_ok
	  { $store->rollback }
	  'rollback';
	$store->unlock;
    }

    return $self;
}

sub is_named_table_in {
    my $self   = shift;
    my $name   = shift;
    my @tables = @_;
    scalar grep {/^`?$name`?$/i} @tables;
}

1;
