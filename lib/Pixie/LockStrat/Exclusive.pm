##
# NAME
#   Pixie::LockStrat::Exclusive - exclusive locking strategy for Pixie
#
# SYNOPSIS
#   use Pixie::LockStrat::Exclusive;
#   # see Pixie::LockStrat;
#
# DESCRIPTION
#   This class implements a locking strategy where:
#
#    *  get's are locked until you release the lock
#       (ie: until this object is destroyed)
#    *  store's are locked 'atomically'
#
##

package Pixie::LockStrat::Exclusive;

use strict;

use base qw( Pixie::LockStrat );

our $VERSION = '2.08_02';

sub pre_get {
  my $self = shift;
  my($oid,$pixie) = @_;
  $pixie->store->lock_object_for($oid, $pixie);
}

sub post_get {
}

1;
