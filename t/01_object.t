##
## Pixie 'non-hash' (ie: blessed array) tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More qw( no_plan );

BEGIN { use_ok( 'Pixie::Object' ) }

ok( $Pixie::Object::VERSION, 'version' );

my $test = pxTestObject->new( 123 );
isa_ok( $test, 'pxTestObject', 'new' );
is    ( $test->{init}, 123,    'init called');
can_ok( $test, 'subclass_responsibility' );

# don't use Test::Exception here - it skews the level of caller
eval { $test->abstract( 123 ) };
like( $@, qr/abstract not implemented for pxTestObject/,
      ' abstract methods die' );

BEGIN {
    package pxTestObject;
    use base qw( Pixie::Object );
    # init should be called by new()
    sub init {
	my $self = shift;
	$self->{init} = shift;
    }
    sub abstract {
	shift->subclass_responsibility( @_ );
    }
};
