##
## Pixie::ObjectGraph tests
##

use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;
use Test::MockObject;

BEGIN { use_ok( 'Pixie::ObjectGraph' ); }

my $graph = Pixie::ObjectGraph->new;

## add_edge
is( $graph->add_edge( foo => 'bar' ), $graph, 'add_edge' );

## neighbours
my $oids = $graph->neighbours( 'foo' );
my @oids = $graph->neighbours( 'foo' );

isa_ok( $oids, 'ARRAY',    '(scalar) neighbours' );
is    ( $oids->[0], 'bar', ' expected oid' );
is    ( @oids, 1,          '(array) neighbours expected size' );
is    ( $oids[0], 'bar',   '(array) neighbours expected oid' );

## add_graph
my $graph2 = Pixie::ObjectGraph->new
  ->add_edge( foo => 'baz' )
  ->add_edge( bar => 'foo' );

is( $graph->add_graph( $graph2 ), $graph, 'add_graph' );

my @foos = $graph->neighbours( 'foo' );
my @bars = $graph->neighbours( 'bar' );
is( $foos[0], 'baz', ' foo edges overwritten' );
is( $bars[0], 'foo', ' new edges added' );

