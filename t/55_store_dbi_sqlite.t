##
## Tests for Pixie::Store::DBI::SQLite
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use File::Spec;
use File::Basename qw( dirname );
use Test::More;
use Test::Exception;

use Common;
use MockPixie qw( $pixie );

BEGIN {
    plan( skip_all => "DBD::SQLite not available" ) unless ($Common::SQLITE_AVAIL);
    plan 'no_plan';
}

BEGIN {
    use_ok( 'Pixie::Store::DBI::Default' );
    use_ok( 'Pixie::Store::DBI::SQLite' );
}

our @rm_files;
END { unlink @rm_files; }


## TODO: remove these tests if mkpath patch gets accepted into DBD::SQLite
my $class = 'Pixie::Store::DBI::SQLite';
my $path  = $class->get_path_from_dsn( $Common::SQLITE_DSN );
is( $path, $Common::SQLITE_FILE, 'get_path_from_dsn' );

$class->create_dir_for_dsn( $Common::SQLITE_DSN );
ok( -d dirname( $Common::SQLITE_FILE ), 'create_dir_for_dsn' );
## end of remove TODO

foreach my $dsn (Common->sqlite_stores) {
    print "testing $dsn...\n";

    push @rm_files, Pixie::Store::DBI::SQLite->get_path_from_dsn( $dsn );

    my $tester = StoreTests::SQLite->new
      ->dsn( $dsn )
      ->store_class( 'Pixie::Store::DBI::SQLite' )
      ->run_tests;
}

package StoreTests::SQLite;

use Test::More;
use base qw( StoreTests::DBI );

sub test_deploy {
    my $self = shift;

    $self->SUPER::test_deploy;
    ## TODO: remove if mkpath patch gets accepted into DBD::SQLite
    my $path = Pixie::Store::DBI::SQLite->get_path_from_dsn( $self->dsn );
    ok( -e $path, "creates sqlite file ($path)" );

    return $self;
}

