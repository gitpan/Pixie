package Pixie::LockStrat::Exclusive;

use strict;

use base 'Pixie::LockStrat';

sub pre_get {
  my $self = shift;
  my($oid,$pixie) = @_;

  $pixie->store->lock_object_for($oid, $pixie);
}

sub post_get {
}

1;
