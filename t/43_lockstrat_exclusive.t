##
## Pixie::LockStrat::Exclusive tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;

use MockPixie qw( $pixie );

BEGIN { use_ok( 'Pixie::LockStrat::Exclusive' ); }

my $strat = Pixie::LockStrat::Exclusive->new;

## pre_store
$pixie->set_always( 'store', $pixie )
      ->set_always( 'lock_object_for', 'locked' );
is( $strat->pre_get( 'my oid', $pixie ), 'locked', 'pre_get' );

$strat->{on_DESTROY_called} = 1; # avoid warning
