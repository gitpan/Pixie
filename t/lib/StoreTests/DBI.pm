##
## Common tests for DBI-based Pixie Stores
##

package StoreTests::DBI;

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Pixie::Store::DBI;

use base qw( StoreTests );
use accessors qw( username password );

$Pixie::Store::DBI::Default::LOCK_TIMEOUT = 0;

sub run_tests {
    my $self = shift;
    $self->test_deploy_with_named_tables
	 ->SUPER::run_tests( @_ )
}

sub test_deploy_with_named_tables {
    my $self   = shift;
    my %tables = ( object_table  => 'px_otest',
		   lock_table    => 'px_ltest',
		   rootset_table => 'px_rtest' );

    # just in case some got left lying around:
    $self->del_tables( [ values %tables ] );

    ok( Pixie::Store::DBI->deploy( $self->dsn, %tables ),
	'deploy (named tables)' );

    $self->check_tables_exist( \%tables )
         ->del_tables( [ values %tables ] );
}

sub test_deploy {
    my $self = shift;

    $self->del_tables; # just in case some got left lying around

    $self->SUPER::test_deploy( @_ )
         ->check_tables_exist;
}

sub check_tables_exist {
    my $self   = shift;
    my $tables = shift || { object_table  => 'px_object',
			    lock_table    => 'px_lock_info',
			    rootset_table => 'px_rootset' };
    my $dbh    = $self->new_dbh;
    my @tables = $dbh->tables( '', '', 'px%' );

    ok( $self->is_named_table_in( $tables->{object_table} => @tables ),
	"object table ($tables->{object_table}) created" );

    ok( $self->is_named_table_in( $tables->{lock_table} => @tables ),
	"lock table ($tables->{lock_table}) created" );

    ok( $self->is_named_table_in( $tables->{rootset_table} => @tables ),
	"rootset table ($tables->{rootset_table}) created" );

  TODO: {
	local $TODO = 'implement object graphs as tables';
	$tables->{object_graph_table} ||= ''; # avoid warnings
	ok( $self->is_named_table_in( $tables->{object_graph_table} => @tables ),
	    "object graph table ($tables->{object_graph_table}) created" );
    }

    return $self;
}

sub is_named_table_in {
    my $self   = shift;
    my $name   = shift;
    my @tables = @_;
    scalar grep {/^$name$/i} @tables;
}

sub test_connect {
    my $self = shift;

    dies_ok
      { Pixie::Store::DBI->connect( $self->dsn, object_table => 'nonexistent') }
      'connect( object_table => nonexistent )';

    $self->SUPER::test_connect( @_ );
}

sub test_locking {
    my $self  = shift;
    $self->test_lock_unlock
         ->test_rollback
	 ->test_lock_for;
}

sub test_lock_unlock {
    my $self  = shift;
    my $store = $self->store;
    my $dbh   = $self->store->get_dbh;

    is( $store->lock, $store, 'lock' );
    ok( !$dbh->{AutoCommit},  'auto commit is off' );

    $dbh->do( "INSERT INTO " . $store->lock_table .
	      " ( px_oid, px_locker ) " .
	      " VALUES ( 'test', 'unlock test' )" );

    is( $store->unlock, $store,   'unlock' );
    ok( $dbh->{AutoCommit},       'auto commit is on' );

    my @rows = $dbh->selectrow_array
      ( "SELECT px_locker FROM " . $store->lock_table .
	" WHERE px_oid = 'test'" );
    is( $rows[0], 'unlock test', 'insert was committed' );

    $dbh->do( "DELETE FROM " . $store->lock_table .
	      " WHERE px_oid = 'test'" );

    return $self;
}

sub test_rollback {
    my $self  = shift;
    my $store = $self->store;
    my $dbh   = $self->store->get_dbh;

    $store->lock;
    $dbh->do( "INSERT INTO " . $store->lock_table .
	      " ( px_oid, px_locker ) " .
	      " VALUES ( 'test', 'rollback test' )" );

    is( $store->rollback, $store, 'rollback' );
    ok( $dbh->{AutoCommit},       'auto commit is on' );

    my @rows = $dbh->selectrow_array
      ( "SELECT px_locker FROM " . $store->lock_table .
	" WHERE px_oid = 'test'" );
    is( scalar @rows, 0, 'insert wasnt committed' );

    return $self;
}

sub test_lock_for {
    my $self  = shift;
    my $store = $self->store;
    my $dbh   = $self->store->get_dbh;
    my $oid   = 'test oid';
    my $px1   = Test::MockObject->new->set_always( _oid => 'px1' );

    ok( $store->lock_object_for( $oid, $px1 ),   'lock_object_for px1' );
    is( $store->locker_for( $oid ), 'px1',       'locker_for' );
    ok( $store->unlock_object_for( $oid, $px1 ), 'unlock_object_for px1' );
    ok(!$store->locker_for( $oid ),              'locker_for' );

    return $self;
}

sub new_dbh {
    my $self = shift;
    DBI->connect(
		 $self->dsn,
		 $self->username,
		 $self->password,
		 {AutoCommit => 1, PrintError => 0, RaiseError => 1,}
		);
}

sub del_tables {
    my $self   = shift;
    my $tables = shift || [qw( px_object px_lock_info px_rootset )];
    my $dbh    = eval { $self->new_dbh };

    if ($dbh) {
	foreach my $table ( @$tables ) {
	    eval { $dbh->do( "DROP TABLE $table" ) };
	}
    }

    $self;
}

sub DESTROY {
    my $self = shift;
    $self->del_tables;
    $self->SUPER::DESTROY( @_ );
}

1;
