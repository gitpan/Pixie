package Pixie::Name;

use strict;

our $VERSION = '2.08_02';

# TODO: Pixie::Object has a constructor - use it?
sub new {
  my $class = shift;
  return bless {}, $class;
}

#-----------------------------------------------------------------------------
# Class methods
#-----------------------------------------------------------------------------

sub oid_for_name {
    my $class = $_[0];
    return "<NAME:$_[1]>";
}

# TODO: move these class methods into Pixie ?  They seem out of place here.

# TODO: rename 'name_objects'
sub name_object_in {
  my $class = shift;
  my($name,$obj,$pixie) = @_;
  $pixie->insert
    ( $class->new->_oid($class->oid_for_name($name))->px_target($obj) );
}

# TODO: rename 'fetch_named_objects'
sub get_object_from {
  my $class = shift;
  my($name, $pixie, $strategy) = @_;
  $class->do_restoration
    ( defined($strategy)
      ? $pixie->get_with_strategy( $class->oid_for_name($name), $strategy )
      : $pixie->get($class->oid_for_name($name))
    );
}

# TODO: rename 'restore_targets'
sub do_restoration {
  my $class    = shift;
  my $name_obj = shift || return;
  my $target   = $name_obj->px_target;

  if (wantarray) {
    return map { eval { $_->px_restore } || $_ } @$target;
  }

  if ($target->[-1]->isa('Pixie::Proxy')) {
    return $target->[-1]->px_restore;
  }

  return $target->[-1];
}

# TODO: rename 'fetch_named_objects_with_strategy'
sub get_object_from_with_strategy {
  my $class = shift;
  my($name, $pixie, $strategy) = @_;
  $class->do_restoration
    ($pixie->get_with_strategy($class->oid_for_name($name), $strategy));
}

# TODO: rename 'remove_name_from_objects'
sub remove_name_from {
  my $class = shift;
  my($name, $pixie) = @_;
  $pixie->delete($class->oid_for_name($name));
}


#-----------------------------------------------------------------------------
# Accessors
#-----------------------------------------------------------------------------

sub _oid {
  my $self = shift;
  if (@_) {
    $self->{_oid} = shift;
    return $self;
  } else {
    return $self->{_oid};
  }
}

sub px_target {
  my $self = shift;
  if (@_) {
    $self->{target} = shift;
    return $self;
  } else {
    return $self->{target};
  }
}

1;
