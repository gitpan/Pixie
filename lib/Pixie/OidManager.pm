package Pixie::OidManager;

use strict;

use Pixie::Object;
use base 'Pixie::Object';

our $VERSION = '2.02';

use Data::UUID;
use Scalar::Util qw/blessed weaken/;

sub init {
  my $self = shift;
  $self->{_oidmap} = {};

  $self->{_oidmaker} = Data::UUID->new;
  return $self;
}

sub set_pixie {
  my $self = shift;
  my $pixie = shift;
  $self->{pixie} = $pixie;
  weaken $self->{pixie};
  return $self;
}

sub bind_object_to_oid {
  my $self = shift;
  my($obj, $oid) = @_;
  $self->{_oidmap}{$self->get_key_for($obj)} = $oid;
}

sub forget_object {
  my $self = shift;
  my $obj = shift;
  my $key = $self->get_key_for($obj);
  if (my $oid = $self->{_oidmap}{$key}) {
    delete $self->{_oidmap}{$self->get_key_for($obj)};
    if ( defined($self->{pixie}) ) {
      my $cached = $self->{pixie}->cache_get($oid);
      if (defined($cached)) {
        my $cached_key = $self->get_key_for($cached);
        $self->{pixie}->cache_delete($oid) if $cached_key == $key;
      }
      else {
        $self->{pixie}->cache_delete($oid);
      }
    }
  }
}

sub get_oid_for {
  my $self = shift;
  my $obj = shift;

  return unless defined $obj;
  die "You should't call this on a Pixie::ObjectInfo" if 
    eval { $obj->isa('Pixie::ObjectInfo') };

  my $obj_key = $self->get_key_for($obj);

  return $self->{_oidmap}{$obj_key} if $self->{_oidmap}{$obj_key};

  return $self->{_oidmap}{$obj_key} =
    (blessed($obj) and $obj->can('_oid')) ? $obj->_oid :
      $self->{_oidmaker}->create_str;
}

sub get_key_for {
  my $self = shift;
  my $obj = shift;

  if ( overload::Overloaded($obj) ) {
    my $orig_class = ref($obj);
    bless $obj, 'Class::Whitehole';
    my $retval = 0 + $obj;
    bless $obj, $orig_class;
    return $retval;
  }
  else {
    return 0 + $obj;
  }
}

1;
