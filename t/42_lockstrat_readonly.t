##
## Pixie::LockStrat tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;

use MockPixie qw( $pixie );

BEGIN { use_ok( 'Pixie::LockStrat::ReadOnly' ); }

my $strat = Pixie::LockStrat::ReadOnly->new;

## pre_store
dies_ok { $strat->pre_store( 'my oid', $pixie ) } 'pre_store';

$strat->{on_DESTROY_called} = 1; # avoid warning
