package Pixie::Name;

use strict;

our $VERSION='2.05';

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
  my($name, $pixie, $strategy) = @_;
  $proto->do_restoration( defined($strategy) ?
			  $pixie
			    ->get_with_strategy("<NAME:$name>", $strategy) :
			  $pixie->get("<NAME:$name>"));
}

sub do_restoration {
  my $self = shift;

  return unless my $name_obj = shift;
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

sub get_object_from_with_strategy {
  my $proto = shift;
  my($name, $pixie, $strategy) = @_;
  $proto->do_restoration($pixie->get_with_strategy("<NAME:$name>"));
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
