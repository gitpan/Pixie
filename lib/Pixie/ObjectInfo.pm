package Pixie::ObjectInfo;

use strict;

use Carp qw( croak confess );
use Data::UUID;
use Scalar::Util qw( weaken );

our $VERSION = "2.08_02";

# TODO: Pixie::Object has a constructor - use it?
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = bless {}, $class;
  $self->init();
  return $self;
}

# TODO: rename 'new_from_object'
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
  $self->_oid; # TODO: rename _create_oid for readability?
  return $self;
}

# TODO: split this up into _create_oid()
# (even better would be to make a new class called Pixie::OID)
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

sub set_lock_strategy {
  my $self = shift;
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
  $self->{pixie}->_oid || '' if $self->{pixie};
}

sub px_insertion_thaw { shift }

sub DESTROY {
  my $self = shift;
  local $@; # Protect $@
  if ($self->{pixie}) {
    $self->{pixie}->cache_delete($self->_oid);
    ($self->{lock_strat} ||= Pixie::LockStrat::Null->new)
        ->on_DESTROY(scalar($self->_oid), $self->{pixie});
  }
}

1;
