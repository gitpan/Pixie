package Pixie::Object;

use strict;
use Carp qw( confess croak );

our $VERSION = "2.08_02";

sub new {
  my $class = shift;
  my $self  =  bless {}, $class;
  $self->init( @_ );
  return $self;
}

sub init { $_[0]; }

sub subclass_responsibility {
  my $self = shift;
  croak( (caller(1))[3], " not implemented for ", ref($self) );
  return wantarray ? @_ : $_[-1];
}

1;
