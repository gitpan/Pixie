##
# NAME
#   Pixie::LockStrat::ReadOnly - read only locking strategy for Pixie
#
# SYNOPSIS
#   use Pixie::LockStrat::ReadOnly;
#   # see Pixie::LockStrat;
#
# DESCRIPTION
#   This class implements a locking strategy where:
#
#    *  store's are not allowed (will die).
#
##

package Pixie::LockStrat::ReadOnly;

use strict;

use Carp qw( confess croak );

use base qw( Pixie::LockStrat );

our $VERSION = '2.08_02';

sub pre_store {
  my $self = shift;
  my $oid = shift;
  # TODO: confess
  croak "$oid: Object is read only";
}

1;
