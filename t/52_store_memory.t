##
## Tests for Pixie::Store::Memory
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;

use StoreTests;
use MockPixie qw( $pixie );

BEGIN { use_ok( 'Pixie::Store::Memory' ); }

my $tester = StoreTests::Memory->new
  ->dsn( 'memory' )
  ->store_class( 'Pixie::Store::Memory' )
  ->run_tests;


package StoreTests::Memory;

use Test::More;
use base qw( StoreTests );

sub test_deploy {
    my $self = shift;

    my $store = $self->constructor_store_class->deploy( $self->dsn );
    TODO: {
	local $TODO = 'make deploy return a new obj';
	isa_ok( $store, $self->store_class, 'deploy' );
    }
    ## TODO: when the above passes, remove this sub-class

    return $self;
}
