package Pixie::Object;

use strict;

our $VERSION='2.05';

sub new {
  my $proto = shift;
  my $self =  bless {}, $proto;
  $self->init;
  return $self;
}

sub init { $_[0]; }

1;
