##
## Tests for Pixie::Store::DBI
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );

BEGIN { use_ok( 'Pixie::Store::DBI' ); }

my $class = 'Pixie::Store::DBI';
{
    no warnings;
    local *Pixie::Store::DBI::Default::deploy   = sub { 'deploy'  };
    local *Pixie::Store::DBI::Default::connect  = sub { 'connect' };
    local *Pixie::Store::DBI::Default::_raw_connect = sub { 'rconnect' };
    use warnings;

    is( $class->deploy,       'deploy', 'deploy' );
    is( $class->connect,      'connect', 'connect' );
    is( $class->_raw_connect, 'rconnect', '_raw_connect' );
}
