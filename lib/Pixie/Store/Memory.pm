package Pixie::Store::Memory;

our $VERSION = '2.01';

use Storable qw/nfreeze thaw/;

use base qw/Pixie::Store/;

sub new {
  my $proto = shift;
  my $self = bless {}, $proto;
  $self->init;
  return $self;
}

sub init {
  return $_[0];
}


sub connect {
  my $self = shift;
  $self = ref($self) ? $self : $self->new;
}

sub delete {
  my $self = shift;
  my($oid) = @_;

  defined(delete($$self{$oid})) ? 1 : 0;
}

sub store_at {
  my $self = shift;
  my($oid, $obj) = @_;

  if ($oid) {
    $self->{$oid} = nfreeze($obj);
    return($oid, $obj);
  }
  else {
    return $obj;
  }
}

sub get_object_at {
  my $self = shift;
  my($oid) = @_;

  return thaw $self->{$oid};
}

sub lock { }
sub unlock { }
sub rollback { }

sub clear {
  my $self = shift;
  %$self = ();
  return $self;
}

sub delete_object_at {
  my $self = shift;
  my($oid) = @_;

  if (defined(wantarray)) {
    return thaw delete $self->{$oid};
  }
  else {
    delete $self->{$oid};
  }
}

1;
