package Pixie::LockStrat;

use base 'Pixie::Object';

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
  local $@;
  my ($oid, $pixie) = @_;
  eval { $pixie->store->unlock_object_for($oid, $pixie) };
}

1;
