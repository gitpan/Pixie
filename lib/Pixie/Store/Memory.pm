package Pixie::Store::Memory;

our $VERSION="2.06";

use Storable qw/nfreeze thaw/;

use base qw/Pixie::Store/;

sub new {
  my $proto = shift;
  my $self = bless {}, $proto;
  $self->init;
  return $self;
}

sub init {
  my $self = shift;
  $self->{store} = {};
  $self->{rootset} = {};
  return $self;
}


sub connect {
  my $self = shift;
  $self = ref($self) ? $self : $self->new;
}

sub remove_from_rootset {
  my $self = shift;
  my $oid = shift;
  delete $self->{rootset}{$oid};
  return $self;
}


sub _add_to_rootset {
  my $self = shift;
  my $thing = shift;
  $self->{rootset}{$thing->PIXIE::oid} = 1;
  return $self;
}

sub rootset {
  my $self = shift;
  keys %{$self->{rootset}};
}


sub working_set_for {
  my $self = shift;
  my @ret = keys %{$self->{store}};
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

sub lock { }
sub unlock { }
sub rollback { }

sub clear {
  my $self = shift;

  %{$self->{store}} = ();
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
