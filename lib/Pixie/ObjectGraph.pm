##
# NAME
#   Pixie::ObjectGraph - graph of associated object id's in a Pixie store
#
# SYNOPSIS
#   use Pixie::ObjectGraph;
#   my $graph = Pixie::ObjectGraph->new;
#
#   $graph->add_edge( $oid_source => $oid_dest1 )
#         ->add_edge( $oid_source => $oid_dest2 );
#
#   @oids = $graph->neighbours( $oid_source ); # dest1-2
#
# DESCRIPTION
#   ObjectGraphs look like this internally:
#
#   $graph = {
#	    source_oid1 => [qw( dest_oid1, dest_oid2, dest_oid3 )],
#	    source_oid2 => [qw( dest_oid1, dest_oid4, dest_oid5 )],
#	    ...
#	   };
##

package Pixie::ObjectGraph;

use strict;
use warnings;

our $VERSION = '2.08_02';

# TODO: Pixie::Object has a constructor - use it?
sub new {
  my $proto = shift;
  return bless {}, $proto;
}

## TODO: rename 'associate_oids' ?
sub add_edge {
  my $self = shift;
  my($source => $dest) = @_;

  push @{$self->{$source}}, $dest;
  return $self;
}

## TODO: rename 'edges'? 'associated_oids'?
sub neighbours {
  my $self = shift;
  my $source = shift;
  my @retary = exists($self->{$source}) ? @{$self->{$source}} : ();
  wantarray ? @retary : [@retary];
}

sub add_graph {
  my $self = shift;
  my $other_graph = shift;

  @{$self}{keys %$other_graph} = values %$other_graph;
  return $self;
}

1;
