package Pixie::ObjectInfo;

use strict;

our $VERSION = '2.03';
use Data::UUID;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = bless {}, $class;
    $self->init();
    return $self;
}

sub init {
    my $self = shift;
    $self->_oid;
    return $self;
}

sub px_is_not_proxiable { 1 }

{
    my $uuid_maker;
    sub _oid {
	my $self = shift;
	$self->{_oid} ||=
	  ( $uuid_maker ||= Data::UUID->new() )->create_str();
	if (wantarray) {
	    return $self->{_oid}, 0;
	}
	else {
	    return $self->{_oid};
	}
    }
}

sub set__oid {
    my $self = shift;
    $self->{_oid} = shift;
}

sub the_store {
  my $self = shift;
  if (@_) {
    return $self;
  }
  else {
    return;
  }
}

sub insertion_thaw { shift }

1;
