package Pixie::Hook;

use strict;
use warnings::register;
no warnings "redefine";

use Data::Dumper;

our $VERSION = '2.03';

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

  # Set up Data::Dumper to do the right thing
  local $Data::Dumper::Freezer = 'Freeze';
  local $Data::Dumper::Toaster = 'Thaw';
  local $Data::Dumper::Bless = 'Pixie::Hook::Bless';
  my $datastring = $self->data_as_string( $struct );
  use subs qw ( Pixie::Hook::Bless );
  {
    my $VAR1;
    local *Bless = sub {
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

# Set some 'catchers' for our Freeze and Thaw methods.
sub UNIVERSAL::Freeze {
    return $_[0];
}

sub UNIVERSAL::Thaw {
    return $_[0];
}

1;
