##
# NAME
#   Pixie::LockStrat - base class for locking strategies in Pixie
#
# SYNOPSIS
#   use Pixie::LockStrat;
#
#   my $strat = Pixie::LockStrat->new;
#   $pre_get_status = $strat->pre_get( $oid, $pixie );
#   $strat->post_get( $oid, $pixie, $pre_get_status );
#   $pre_store_status = $strat->pre_store( $oid, $pixie );
#   $strat->post_store( $oid, $pixie, $pre_store_status );
#
#   $strat->on_DESTROY; # call from your DESTROY
#
# DESCRIPTION
#   Pixie::LockStrat's are used by Pixie to control access to the
#   store.  This class implements a basic locking strategy where:
#
#    *  get's are not locked
#    *  store's are locked 'atomically'
#
#   Pixie defines what 'atomically' means.
#
# NOTES
#   At the moment, everything implemented as class methods.
#
##

package Pixie::LockStrat;

use strict;
use warnings;

use Carp qw( carp );
use Scalar::Util qw( blessed );

use base qw( Pixie::Object );

our $VERSION = '2.08_02';

sub pre_get {}

sub post_get {}

sub pre_store {
  my $self = shift;
  my($oid, $pixie) = @_;
  $pixie->store->lock_object_for($oid, $pixie);
}

sub post_store {
  my $self = shift;
  my ($oid, $pixie, $pre_status) = @_;
  $pixie->store->unlock_object_for($oid, $pixie) if $pre_status;
}

sub on_DESTROY {
  my $self = shift;
  my ($oid, $pixie) = @_;
  local $@;  # preserve errors
  $self->{on_DESTROY_called} = 1;
  my $store = $pixie->store;
  $store->unlock_object_for($oid, $pixie) if $store;
}

sub DESTROY {
    carp( blessed( $_[0] ) . " destroyed before on_DESTROY called" )
      unless $_[0]->{on_DESTROY_called};
}

1;
