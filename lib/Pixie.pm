package Pixie;

=head1 NAME

Pixie - The magic data pixie

=head1 SYNOPSIS

  use Pixie;

  my $pixie = Pixie->new->connect('dbi:mysql:dbname=test', $user, $pass);

  # Save an object
  my $cookie = $pixie->insert($some_object);

  undef($some_object);

  # Get it back
  my $some_object = $pixie->get($cookie);

=head1 DESCRIPTION

Pixie is yet another object persistence tool. The basic goal of Pixie
is that it should be possible to throw any object you want at a data
pixie and the pixie will just tuck it away in its magic sack, giving
you a cookie in exchange. Then, minutes, hours or days later, you can
show the pixie your cookie and get the object back.

No schemas. No complex querying. No refusing to handle blessed arrays.

How does pixie do this? Well... when we said 'any object' we were
being slightly disingenuous. As far as Pixie is concerned 'any object'
means 'any object that satisfies any of these criteria':

=over 4

=item *

The toplevel object is a blessed hash.

=item *

The toplevel object is a blessed array and C<$object-E<gt>can('_oid')> (it
is a good idea if the _oid returned is unique, for appropriate values of 'unique'.

=back

Once you get below the toplevel of a composed object there is no
longer a requirment for classes that are represented by blessed arrays
to implement the C<_oid> method (though if you do not implement
C<_oid>) you will almost certainly find that multiple objects that
point to the same blessed array will no longer do so after they have
been saved and restored. Which may not be what you want...

Right now, Pixie can only save blessed hashes and blessed arrays, but
it should be possible to extend it to support 'bless arbitrary
scalars'. However, during testing we found that blessed arbitrary
scalars were often used with XS classes that stored extra data where
Storable and Data::Dumper could not see it, leading to all sorts of
horrors on restoration. So we turned that feature off pending a better
approach.

=cut

use strict;
use warnings::register;

use Data::UUID;
use Pixie::Hook;
use Pixie::Proxy;
use Data::Dumper;
use Scalar::Util qw/ blessed weaken /;

use Pixie::Store;

our $VERSION = '2.01';

sub new {
  my $class = shift;
  my $self  = {cache => {},};
  bless $self, $class;

  $self->init();

  return $self;
}

sub init {
  my $self = shift;

  $self->hook( Pixie::Hook->new() );
  $self->connect('memory');
  return $self;
}

sub connect {
  my $self = shift;
  $self = $self->new unless ref $self;
  $self->store( Pixie::Store->connect(@_) );
}

sub clear_storage {
  my $self = shift;
  $self->store->clear;
}

sub hook {
  my $self = shift;
  my $hook = shift;
  if (defined($hook)) {
    $self->{hook} = $hook;
    return $self;
  } else {
    return $self->{hook};
  }
}

sub store {
  my $self = shift;
  my $s    = shift;
  if (defined($s)) {
    $self->{store} = $s;
    return $self;
  } else {
    return $self->{store};
  }
}

sub store_individual {
  my $self = shift;
  my $real = shift;

  my $oid = $self->oid( $real );
  if (defined($oid)) {
    if ($Pixie::Stored{$oid}) {
      return $Pixie::Stored{$oid};
    }
    else {
      $self->cache_insert($real);
      return $self->make_proxy($self->store->store_at($oid => $real));
    }
  }
  else {
    return $real;
  }
}

sub make_proxy {
  my $self = shift;

  Pixie::Proxy->make_proxy(@_);
}

sub oid {
  my $self = shift;
  my $real = shift;
  return unless defined $real;

  if (blessed($real) && $real->can('_oid')) {
    if (wantarray) {
      return( $real->_oid, 0);
    } else {
      return $real->_oid;
    }
  } elsif ($real->isa('HASH')) {
    if (defined( $real->{_oid} )) {
      if (wantarray) {
        return ($real->{_oid}, 0);
      } else {
        return $real->{_oid};
      }
    }
    else {
      my $oid = Data::UUID->new()->create_str();
      $real->{_oid} = $oid;
      if (wantarray) {
        return ($oid, 1)
      } else {
        return $oid;
      }
    }
  } else {
    return;
  }
}

sub insert {
  my $self = shift;
  my $this = shift;

  local %Pixie::Stored;
  $self->oid($this);
  $self->cache_insert($this);

  my $thissub = sub {
    my $struct = shift;
    my $class  = shift;

    unless ($self->can_store($struct, $class)) {
      warnings::warn("Don't know how to insert a $class");
      return undef;
    }
    return CORE::bless $struct, $class if
        (UNIVERSAL::isa($class => 'Pixie::Proxy') &&
         !UNIVERSAL::isa($class => 'Pixie::Name'));
    return $self->store_individual( $self->make_new_object($struct, $class) );
  };
  $self->lock_store;
  my $proxy =  eval { $self->hook->objecthook( $this, $thissub ) };
  if ($@) {
    $self->rollback_store;
    $self->unlock_store;
    die $@;
  }
  else {
    $self->unlock_store;
    defined($proxy) ? $proxy->_oid : undef;
  }
}

sub can_store {
  my $self = shift;
  my($thing,$class) = @_;

  if(ref($thing) =~ /CODE|Regexp/) {
    return undef unless $class->can('STORABLE_freeze');
  }
  return 1;
}

sub get {
  my $self = shift;
  $self->lock_store;
  my $res = eval { $self->_get(@_) };
  $self->unlock_store;
  die $@ if $@;
  return $res;
}

sub delete {
  my $self = shift;
  my $obj_or_oid  = shift;

  my $oid = ref($obj_or_oid) ? $self->oid($obj_or_oid) : $obj_or_oid;
  $self->store->delete($oid);
}

sub lock_store     { $_[0]->store->lock; }
sub unlock_store   { $_[0]->store->unlock; }
sub rollback_store { $_[0]->store->rollback; }

sub _get {
  my $self = shift;
  my $oid  = shift;

  return undef unless defined $oid;
  my $cached_struct = $self->cache_get($oid);
  return $cached_struct if defined($cached_struct);
  my $rawstruct = $self->store->get_object_at( $oid );
  return unless defined($rawstruct);
  my $thissub = sub {
    my $struct = shift;
    my $class  = shift;
    my $blessed = undef;
    if ($class->isa('Pixie::Proxy')) {
      $blessed = CORE::bless( $struct, $class );
      my $oid = $blessed->_oid;
      my $ret = $self->cache_get($oid);
      if (defined($ret)) {
        bless $blessed, 'Class::Whitehole';
        return $self->cache_insert($ret);
      }
      else {
        return  $self->cache_insert($blessed->the_store($self));
      }
    } else {
      return $self->cache_insert($self->make_new_object($struct, $class));
    }
  };
  my $ret = $self->hook->objecthook( $rawstruct, $thissub );
  bless $rawstruct, 'Class::Whitehole';
  $self->cache_insert($ret);
  return $ret;
}

sub make_new_object {
  my $self = shift;
  my($struct, $class) = @_;

  my $real = eval { local *bless = \&CORE::bless;
                    $class->new };
  if ($@) {
    $real = CORE::bless $struct, $class;
  }
  else {
    my $type = ref($struct);

    if ($type eq 'SCALAR') {
      $$real = $$struct;
    }
    elsif ($type eq 'ARRAY') {
      @$real = @$struct;
    }
    elsif ($type eq 'HASH') {
      %$real = %$struct;
    }
  }
  return $real;
}

sub cache {
  my $self = shift;

  $self->{cache};
}

sub flush_cache {
  my $self = shift;
  %{$self->{cache}} = ();
}

sub cache_insert {
  my $self = shift;
  my $obj = shift;
  my $oid = $self->oid($obj);
  no warnings 'uninitialized';
  if (length($oid) && ! defined($self->{cache}{$oid}) ) {
    $self->{cache}{$oid} = $obj;
    weaken $self->{cache}{$oid};
  }
  return $obj;
}

sub cache_get {
  my $self = shift;
  my $oid = shift;
  defined($oid) || return undef;
  my $val = $self->{cache}{$oid};
  return defined($val)
      ? bless($self->{cache}{$oid}, ref($self->{cache}{$oid})) 
      : undef;
}

sub cache_delete {
  my $self = shift;
  my $oid = shift;
  $oid = $self->oid($oid) if ref $oid;
  delete $self->{cache}{$oid};
}

# The naming section

sub bind_name {
  my $self = shift;
  my($name, @objects) = @_;

  require Pixie::Name;
  Pixie::Name->name_object_in($name, \@objects, $self);
}

sub get_object_named {
  my $self = shift;
  my($name) = @_;
  require Pixie::Name;
  Pixie::Name->get_object_from($name, $self);
}

=head1 AUTHOR

Pixie sprang from the mind of James Duncan, james@fotango.com. Piers
Cawley, pdcawley@bofh.org.uk and Leon Brocard, acme@astray.org are his
co conspiritors.

=cut

1;

