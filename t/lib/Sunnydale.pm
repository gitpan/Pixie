use strict;

package Sunnydale;
use Test::More;
use Carp;

sub leaktest {
  local $TODO;
  is $SunnydaleObject::population, 0, "Leaktest";
  $SunnydaleObject::population = 0;
}

package SunnydaleObject;
use Data::UUID;

our $population = 0;

use overload '""' => 'as_string';

sub new {
  my $proto = shift;
  ++$population;
  my $self = bless { $proto->defaults, @_ }, $proto;
  $self->init;
  return $self;
}

sub init {
  my $self = shift;
  $self->_oid; # setup an oid.
  return $self;
}

sub defaults { return () }

{
  my $oid_maker;
  sub _oid {
    my $self = shift;
    if (@_) {
      $self->{_oid} = $_[0];
      return $self;
    }
    else {
      $self->{_oid} ||= ($oid_maker ||= Data::UUID->new)->create_str;
    }
  }
}

sub DESTROY {
  --$population
}

package Person;

use base 'SunnydaleObject';

our $VERSION='1'; # so use base doesn't autoload Person.pm

sub as_string { die 'subclass responsibility' }

sub name {
  my $self = shift;
  if (@_) {
    $self->{name} = shift;
    return $self;
  }
  else {
    return $self->{name};
  }
}

package IndividualPerson;

use base 'Person';

sub as_string {
  my $self = shift;

  my $name = $self->name;
  my $first_name = $self->first_name;

  if (defined($name) && defined($first_name)) {
    return "$first_name $name";
  }
  elsif (defined $first_name) {
    return $first_name;
  }
  else {
    return $name;
  }
}

sub has_soul {
  my $self = shift;

  if (@_) {
    $self->{has_soul} = shift;
    return $self;
  }
  else {
    return $self->{has_soul};
  }
}

sub first_name {
  my $self = shift;

  if (@_) {
    $self->{first_name} = shift;
    return $self;
  }
  else {
    return $self->{first_name};
  }
}

package Human;

use base 'IndividualPerson';

sub defaults {
  my $proto = shift;

  return( $proto->SUPER::defaults, has_soul => 1 );
}

package Vampire;

use base 'IndividualPerson';

sub defaults {
  my $proto = shift;
  return ($proto->SUPER::defaults, sire => undef, has_soul => 0);
}

sub sire {
  my $self = shift;
  if (@_) {
    $self->{sire} = shift;
    die "Sire must be a vampire" unless $self->{sire}->isa('Vampire');
    return $self;
  }
  else {
    return $self->{sire};
  }
}

package Demon;

use base 'IndividualPerson';

package CorporatePerson;

use base 'Person';

sub as_string {
  my $self = shift;
  $self->name;
}


package EducationalEstablishment;

use base 'CorporatePerson';

sub defaults {
  my $proto = shift;
  return ($proto->SUPER::defaults, on_hellmouth => undef);
}

package Group;

use base 'CorporatePerson';

sub defaults {
  my $proto = shift;
  return ($proto->SUPER::defaults, members => []);
}

sub members {
  my $self = shift;
  if (@_) {
    @{$self->{members}} = @_;
    return $self;
  }
  else {
    return wantarray ? @{$self->{members}} : $self->{members};
  }
}

1;
