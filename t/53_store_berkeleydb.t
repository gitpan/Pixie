##
## Tests for Pixie::Store::BerkeleyDB
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use File::Spec;
use Test::More;
use Test::Exception;

use Common;
use MockPixie qw( $pixie );

BEGIN {
    plan( skip_all => "BerkeleyDB not available" ) unless ($Common::BDB_AVAIL);
    plan 'no_plan';
}

our @files;
BEGIN { use_ok( 'Pixie::Store::BerkeleyDB' ); }
END   { unlink @files; }

foreach my $dsn (Common->bdb_stores) {
    print "testing $dsn...\n";

    push @files, Pixie::Store::BerkeleyDB->get_path_from_dsn( $dsn );

    my $tester = StoreTests::BerkeleyDB->new
      ->dsn( $dsn )
      ->store_class( 'Pixie::Store::BerkeleyDB' )
      ->run_tests;
}

package StoreTests::BerkeleyDB;

use Test::More;
use base qw( StoreTests );

sub test_deploy {
    my $self = shift;

    my $store = $self->constructor_store_class->deploy( $self->dsn );

    ## TODO: when this test passes, move it to StoreTests->test_deploy
    ## (all subclasses should return new obj on deploy)
    TODO: {
	local $TODO = 'make deploy return a new obj';
	isa_ok( $store, $self->store_class, 'deploy' );
    }

    ok( -e $Common::BDB_FILE, 'creates berkeley db file' );

    return $self;
}
