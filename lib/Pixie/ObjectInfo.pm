package Pixie::ObjectInfo;

use strict;

our $VERSION='2.05';

use Scalar::Util qw/weaken/;

use Data::UUID;
use Carp;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = bless {}, $class;
  $self->init();
  return $self;
}

sub make_from {
  my $proto = shift;
  my $obj = shift;
  my $self = $proto->new;
  $self->set__oid($obj->_oid) if $obj->can('_oid');
  $self->set_the_object($obj);
  $self->set_pixie(Pixie->get_the_current_pixie) if
    defined(Pixie->get_the_current_pixie);
  return $self;
}

sub init {
  my $self = shift;
  $self->_oid;
  return $self;
}

{
  my $uuid_maker;
  sub _oid {
    my $self = shift;
    $self->{_oid} ||=
      ( $uuid_maker ||= Data::UUID->new() )->create_str();
    return $self->{_oid};
  }
}

sub set__oid {
  my $self = shift;
  $self->{_oid} = shift;
  return $self;
}

sub set_the_object {
  my $self = shift;
  croak "We already have an object!" if defined($self->{the_object});
  weaken($self->{the_object} = shift);
  return $self;
}

sub the_object {
  my $self = shift;
  $self->{the_object};
}

sub set_the_container {
  my $self = shift;
  croak "We already have a pixie!" if defined($self->{the_container});
  weaken($self->{the_container} = shift);
  return $self;
}

sub the_container {
  my $self = shift;
  $self->{the_container};
}

sub set_lock_strategy {
  my $self = shift;
  croak "We already have a lock strategy!" if defined($self->{lock_strat});
  $self->{lock_strat} = shift;
  return $self;
}

sub lock_strategy {
  my $self = shift;
  $self->{lock_strat};
}

sub set_pixie {
  my $self = shift;
  weaken($self->{pixie} = shift);
  return $self;
}

sub pixie {
  my $self = shift;
  $self->{pixie};
}

sub pixie_id {
  my $self = shift;
  $self->{pixie}->_oid || '';
}

sub px_insertion_thaw { shift }

sub DESTROY {
  my $self = shift;
  local $@; # Protect $@
  if (defined($self->{the_container})) {
    delete $self->{the_container}{$self->_oid};
    $self->{lock_strat}->on_DESTROY(scalar($self->_oid), $self->{pixie}) if
      ($self->{lock_strat} && $self->{pixie});
  }
}

1;
