package Pixie::FinalMethods;

=head1 NAME

Pixie::FinalMethods - 'fixed' methods that Pixie uses

=head1 SYNOPSIS

  use Pixie::FinalMethods;

  $hash{$some_object->PIXIE::address} = ...;

=head1 DESCRIPTION

Pixie has some helper methods that it makes sense to use in an object
oriented fashion any object. But these same methods should I<never> be
overridden. One option is just to define these methods in UNIVERSAL
and to rely on people to be polite. But we are a little more
defensive. We push our final methods into the PIXIE namespace. Perl
allows you to make a method call to a fully specified method name, so
we do that. And it works.

This means that any methods we shove into UNIVERSAL are there to be
overridden L<Pixie::Complicity>, though some are more overrideable
than others.

=cut

$Pixie::FinalMethods::Loaded++;

package PIXIE;

use Pixie::Info;


sub address {
  my $self = shift;
  my $orig_class = ref($self);

  bless $self, 'Class::Whitehole';
  my $addr = 0 + $self;
  bless $self, $orig_class;
  return $addr;
}

sub set_oid {
  my $self = shift;
  $self->PIXIE::get_info->set__oid(shift);
  return $self;
}

sub oid {
  my $self = shift;
  $self->PIXIE::get_info->_oid;
}

sub managing_pixie {
  get_info($_[0])->pixie;
}


sub get_info {
  my $self = shift;
  die "Can't get info about a ", ref($self) if $self->isa('Pixie::ObjectInfo');
  my $info;
  unless ( $info = Pixie::Info::px_get_info($self)) {
    $info = Pixie::ObjectInfo->make_from($self);
    $self->PIXIE::set_info($info);
  }
  return $info;
}

sub set_info {
  my $self = shift;
  my $info = shift;

  die "Can't set info about a ", ref($self) if $self->isa('Pixie::ObjectInfo');
  die "Info must be a Pixie::ObjectInfo" unless defined($info) ? $info->isa('Pixie::ObjectInfo') : 1;
  Pixie::Info::px_set_info($self, $info);
  return $self;
}


1;
