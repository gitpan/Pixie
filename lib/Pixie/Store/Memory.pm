=head1 NAME

Pixie::Store::Memory -- a memory store for Pixie.

=head1 SYNOPSIS

  use Pixie;
  my $px = Pixie->new->connect( 'memory' );

=head1 DESCRIPTION

A memory store for Pixie.

=cut

package Pixie::Store::Memory;

use Carp qw( confess );
use Storable qw( nfreeze thaw );

use base qw( Pixie::Store );

our $VERSION = "2.08_02";

sub init {
  my $self = shift;
  $self->{store}   = {};
  $self->{rootset} = {};
  return $self;
}

sub deploy {
  my $self = shift;
  # do nothing
  return $self;
}

sub connect {
  my $self = shift;
  $self    = ref($self) ? $self : $self->new;
}

sub remove_from_rootset {
  my $self = shift;
  my $oid  = shift;
  delete $self->{rootset}{$oid};
  return $self;
}

sub _add_to_rootset {
  my $self  = shift;
  my $thing = shift;
  $self->{rootset}{$thing->PIXIE::oid} = 1;
  return $self;
}

## TODO: use wantarray
sub rootset {
  my $self = shift;
  keys %{$self->{rootset}};
}

sub working_set_for {
  my $self = shift;
  my @ret  = keys %{$self->{store}};
  return wantarray ? @ret : \@ret;
}

sub _delete {
  my $self = shift;
  my($oid) = @_;
  defined(delete $self->{store}{$oid}) ? 1 : 0;
}

sub store_at {
  my $self = shift;
  my($oid, $obj) = @_;

  # TODO: why not throw an error if no $oid?
  if ($oid) {
    $self->{store}{$oid} = nfreeze($obj);
    return($oid, $obj);
  }
  else {
    return $obj;
  }
}

sub get_object_at {
  my $self = shift;
  my($oid) = @_;

  return thaw $self->{store}{$oid};
}

sub lock { $_[0] }
sub unlock { $_[0] }
sub rollback { $_[0] }

sub clear {
  my $self = shift;
  %{$self->{store}}   = ();
  %{$self->{rootset}} = ();
  return $self;
}

sub delete_object_at {
  my $self = shift;
  my($oid) = @_;

  if (defined(wantarray)) {
    return thaw delete $self->{store}{$oid};
  }
  else {
    delete $self->{store}{$oid};
  }
}

1;

__END__

=head1 SEE ALSO

L<Pixie>, L<Pixie::Store>

=head1 AUTHORS

James Duncan <james@fotango.com>, Piers Cawley <pdcawley@bofh.org.uk>
and Leon Brocard <acme@astray.com>.

Docs by Steve Purkis <spurkis@cpan.org>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Fotango Ltd

This software is released under the same license as Perl itself.

=cut
