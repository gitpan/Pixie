package Pixie::ObjectGraph;

use strict;

sub new {
  my $proto = shift;
  return bless {}, $proto;
}

sub add_edge {
  my $self = shift;
  my($source => $dest) = @_;

  push @{$self->{$source}}, $dest;
  return $self;
}

sub neighbours {
  my $self = shift;
  my $source = shift;
  my @retary = exists($self->{$source}) ? @{$self->{$source}} : ();
  wantarray ? @retary : [@retary];
}

sub DESTROY {
  my $self = shift;
  $self->PIXIE::get_info->pixie->_insert($self);
}

1;
