##
## Pixie::LockStrat tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );

BEGIN { use_ok( 'Pixie::LockStrat::Null' ); }

