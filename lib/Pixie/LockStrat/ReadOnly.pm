package Pixie::LockStrat::ReadOnly;

use strict;
use Carp;

use base 'Pixie::LockStrat';

sub pre_store {
  my $self = shift;
  my $oid = shift;
  croak "$oid: Object is read only";
}

1;
