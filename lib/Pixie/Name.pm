package Pixie::Name;

use strict;

our $VERSION = '2.04';

sub new {
  my $proto = shift;
  return bless {}, $proto;
}

sub name_object_in {
  my $proto = shift;
  my($name,$obj,$pixie) = @_;
  $pixie->insert($proto->new->_oid("<NAME:$name>")
                 ->px_target($obj));
}

sub get_object_from {
  my $proto = shift;
  my($name, $pixie) = @_;
  my $name_obj  = $pixie->get("<NAME:$name>");
  return unless $name_obj;
  my $target = $name_obj->px_target;
  if (wantarray) {
    return map { eval { $_->px_restore } || $_ } @$target;
  }
  else {
    if ($target->[-1]->isa('Pixie::Proxy')) {
      return $target->[-1]->px_restore;
    } else { return $target->[-1]; }
  }
}

sub remove_name_from {
  my $proto = shift;
  my($name, $pixie) = @_;

  $pixie->delete("<NAME:$name>");
}

sub _oid {
  my $self = shift;
  if (@_) {
    $self->{_oid} = shift;
    return $self;
  }
  else {
    return $self->{_oid};
  }
}

sub px_target {
  my $self = shift;
  if (@_) {
    $self->{target} = shift;
    return $self;
  }
  else {
    return $self->{target};
  }
}

1;
