package Pixie::Hook;

use strict;
use warnings::register;
no warnings "redefine";

use Data::Dumper;

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  $self->init();

  return $self;
}

sub init { return $_[0] };

sub objecthook {
  my $self   = shift;
  my $struct = shift;
  my $code   = shift;

  my $datastring = $self->data_as_string( $struct );
  use subs qw ( bless );
  {
    my $VAR1;
    local *bless = sub {
      my $structure = $_[0];
      my $package   = $_[1];
      return $_[0] = $code->( $structure, $package );
    };
    my $done = eval $datastring;
    if ($@) {
      print $@;
      return 0;
    } else {
      return $done;
    }
  }
}

sub data_as_string {
  my $self   = shift;
  my $struct = shift;

  local $Data::Dumper::Deepcopy = 1;
  return Dumper( $struct );
}

1;
