##
## Pixie::Store class method tests
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;

BEGIN { use_ok( 'Pixie::Store' ); }

## as_string
is( Pixie::Store->as_string, 'Pixie::Store', 'as_string' );

## get_type_and_path
my ($type, $path) = Pixie::Store->get_type_and_path( 'test:mytest:dbname=t' );
is( $type, 'test',            'get_type_and_path - type' );
is( $path, 'mytest:dbname=t', 'get_type_and_path - path' );

## load_store_type
dies_ok
  { Pixie::Store->load_store_type( 'non-existent' ) }
  'load_store_type( non-existent type )';

$Pixie::Store::typemap{'test'} = 'NonExistentClass';
dies_ok
  { Pixie::Store->load_store_type( 'test' ) }
  'load_store_type( non-existent type class )';

$Pixie::Store::typemap{'test'} = 'MyTestStore';
lives_ok
  { is( Pixie::Store->load_store_type( 'test' ), 'MyTestStore', 'load_store_type') }
  'load_store_type( valid type )';

## deploy
{
    no warnings;
    local *{ MyTestStore::deploy } = sub { my $class = shift; return \@_ };
    use warnings;
    is_deeply( Pixie::Store->deploy( 'test:mytest:dbname=test', foo => 'bar' ),
	       ['mytest:dbname=test', foo => 'bar'],
	       'deploy as class method' );
}

## connect
{
    no warnings;
    local *{ MyTestStore::connect } = sub {
	my $class = shift;
	bless { args => [@_] }, $class;
    };
    use warnings;
    is_deeply( Pixie::Store->connect( 'test:mytest:dbname=test', foo => 'bar' ),
	       { args => ['mytest:dbname=test', foo => 'bar'],
		 spec =>  'test:mytest:dbname=test' },
	       'connect as class method' );
}

