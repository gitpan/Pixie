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
  $self->{on_DESTROY_called} = 1;
  my $store = $pixie->store;
  $store->unlock_object_for($oid, $pixie) if $store;
}

sub DESTROY {
    warn "LockStrat destroyed" unless $_[0]->{on_DESTROY_called};
}
1;
