##
## Tests for Pixie::Store::DBI::Mysql
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More;

use Common;
use StoreTests::Mysql;

BEGIN {
    eval "use DBD::mysql";
    plan( skip_all => "DBD::mysql not available" ) if $@;
    plan( skip_all => "no mysql stores available" ) unless Common->mysql_stores;
    plan 'no_plan';
}

BEGIN {
    use_ok( 'Pixie::Store::DBI::Default' );
    use_ok( 'Pixie::Store::DBI::Mysql' );
}

foreach my $dsn (Common->mysql_stores) {
    print "testing $dsn...\n";
    my $tester = StoreTests::Mysql->new
      ->dsn( $dsn )
      ->store_class( 'Pixie::Store::DBI::Mysql' )
      ->run_tests;
}
