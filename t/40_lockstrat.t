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

BEGIN { use_ok( 'Pixie::LockStrat' ); }

my $strat = Pixie::LockStrat->new;

## pre_get / post_get
is( $strat->pre_get,  undef, 'pre_get' );
is( $strat->post_get, undef, 'post_get' );

## pre_store
$pixie->set_always( 'store', $pixie )
      ->set_always( 'lock_object_for', 'locked' );
is( $strat->pre_store( 'my oid', $pixie ), 'locked', 'pre_store' );

## post_store
$pixie->set_always( 'unlock_object_for', 'unlocked' );
is( $strat->post_store( 'my oid', $pixie ), undef, 'post_store, no pre_status' );
is( $strat->post_store( 'my oid', $pixie, 1 ), 'unlocked', 'post_store' );

## DESTROY / on_DESTROY
#ok( $strat->DESTROY, 'DESTROY' ); # how to test warning?
is( $strat->on_DESTROY( 'my oid', $pixie ), 'unlocked', 'on_DESTROY' );
ok( $strat->DESTROY, 'DESTROY (on_DESTROY called)' );

