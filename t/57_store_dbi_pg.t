##
## Tests for Pixie::Store::DBI::Pg
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More;

use Common;
use StoreTests::Pg;

BEGIN {
    eval "use DBD::Pg";
    plan( skip_all => "DBD::Pg not available" ) if $@;
    plan( skip_all => "no postgres stores available" ) unless Common->pg_stores;
    plan 'no_plan';
}

BEGIN {
    use_ok( 'Pixie::Store::DBI::Default' );
    use_ok( 'Pixie::Store::DBI::Pg' );
}

foreach my $dsn (Common->pg_stores) {
    print "testing $dsn...\n";
    my $tester = StoreTests::Pg->new
      ->dsn( $dsn )
      ->store_class( 'Pixie::Store::DBI::Pg' )
      ->run_tests;
}
