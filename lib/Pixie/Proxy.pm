package Pixie::Proxy;

use strict;
use warnings::register;
require overload;

# For now we're going to assume that we can only handle hashes or
# array based objects. This may not remain the case.


use Scalar::Util qw/reftype weaken/;

our $AUTOLOAD;

our $VERSION = '2.03';

use Pixie::Object;
use Pixie::ManagedObject;
use base 'Pixie::Object', 'Pixie::ManagedObject';

sub make_proxy {
  my $self = shift;
  my($oid, $obj) = @_;
  my $proxied_class = ref($obj);
  my $real_class = 'Pixie::Proxy::' . reftype($obj);

  $real_class .= '::Overloaded' if overload::Overloaded($proxied_class);
  $real_class->new->_oid($oid)
                  ->class($proxied_class);
}

sub restore {
  my $class = $_[0]->class;
  my $pixie = $_[0]->the_store;
  $_[0]->clear_the_store;
  my $real_obj = $_[0]->fetch_from($pixie);
  return $_[0] = undef unless defined $real_obj;
  $real_obj = $pixie->rebless_into_shadow_class($real_obj);
  $real_obj->_PIXIE_dont_do_real_DEST(1);
  $_[0]->populate_from($real_obj);
  bless $_[0], ref($real_obj);
}

sub fetch_from {
  my $self = shift;
  my $pixie = shift;

  local $pixie->cache->{$self->_oid};
  $pixie->get($self->_oid);
}

sub isa {
  my $self = shift;
  my($class) = @_;
  $self->UNVERSAL::isa($class) || ref($self) && $self->class->isa($class);
}

sub px_is_not_proxiable { 1 }

sub can {
  my $self = shift;
  my($method) = @_;

  $self->UNIVERSAL::can($method) ||
      ref($self) && $self->restore->can($method);
}


{
  my %store_hash;
  sub the_store {
    my $self = shift;
    my $key = $self->_oid;
    if (@_) {
      $store_hash{$key} = shift;
      weaken $store_hash{$key};
      return $self;
    }
    else {
      return $store_hash{$key};
    }
  }

  sub clear_the_store {
    my $self = shift;
    delete $store_hash{$self->_oid};
  }
}

sub STORABLE_freeze {
  my $self = shift;
  my $cloning = shift;
  return if $cloning;

  return $self->_oid, [$self->class];
}

sub STORABLE_thaw {
  my($target, $cloning, $oid, $class) = @_;
  return if $cloning;
  $target->_oid($oid);
  $target->class($class->[0]);
  return $target;
}

sub insertion_thaw { my $self = shift }

sub px_extraction_thaw {
  my $self = shift;
  my $ret = $Pixie::the_current_pixie->cache_get($self->_oid);
  if ( defined $ret ) {
    bless $self, 'Class::Whitehole';
    $Pixie::the_current_pixie->forget_about($self);
    return $ret;
  }
  else {
    $self->the_store($Pixie::the_current_pixie);
    $Pixie::the_current_pixie->cache_insert($self);
    return $self;
  }
}

sub DESTROY {
  my $self = shift;
  return unless ref $self;
  my $store = $self->the_store;
#  return if $Pixie::Proxy::NOCACHEFLUSH;
  $store->forget_about($self) if defined $store;
}

sub AUTOLOAD {
  my $method = $AUTOLOAD;
  $method =~ s/.*:://;
  $_[0]->restore->$method(@_[1..$#_]);
}

package Pixie::Proxy::ARRAY;

use base 'Pixie::Proxy';

sub new {
  my $proto = shift;
  return bless [], $proto;
}

sub _oid {
  my $self = shift;
  if (@_) {
    my $new_oid = shift;
    $self->[0] = "$new_oid";
    return $self;
  } else {
    return $self->[0];
  }
}

sub class {
  my $self = shift;
  if (@_) {
    $self->[1] = shift;
    return $self;
  } else {
    return $self->[1];
  }
}

sub populate_from {
  $#{$_[0]} = 0;
  @{$_[0]} = @{$_[1]};
  return $_[0];
}

package Pixie::Proxy::HASH;

use base 'Pixie::Proxy';

sub new {
  my $proto = shift;

  return bless {}, $proto;
}

sub _oid {
  my $self = shift;
  if (@_) {
    my $new_oid = shift;
    $self->{oid} = "$new_oid";
    return $self;
  } else {
    return $self->{oid};
  }
}

sub class {
  my $self = shift;

  if (@_) {
    $self->{class} = shift;
    return $self;
  } else {
    unless (ref($self)) {
      require Carp;
      Carp::confess "Invalid thing: $self";
    }
    return $self->{class};
  }
}

sub populate_from {
  foreach my $key (keys %{$_[0]}) {
    delete $_[0]->{$key};
  }
  %{$_[0]} = %{$_[1]};
  return $_[0];
}

package Pixie::Proxy::Overloaded;

my %FALLBACK = ( '!' => \&bool_not,
                 '.' => \&concat_str,
                 '""' => \&stringify,
                 'bool' => \&bool,
               );



use overload
    fallback => 0,
    nomethod => sub {
      no strict 'refs';
      my $method = pop;
      my $class = $_[0]->class;
      my $fb = $ {$class . "::()"};
      if ( my $sub = overload::ov_method( overload::mycan($class, "\($method"), $class) ) {
        $_[0]->restore;
        &$sub;
      }
      elsif (!defined($fb) || $fb) {
        # Try falling back
        push @_, $fb;
        if (exists $FALLBACK{$method}) {
          goto &{$FALLBACK{$method}}
        }
        else {
          die "No Fallback found for $method";
        }
      }
      elsif (defined $ {$class . "::()"}) {
        $_[0]->can('nomethod')->(@_, $method);
      }
      else {
        require Carp;
        Carp::confess "Can't find overloaded method for $method";
      }
    };

sub bool_not {
  if ( caller->isa('Pixie::Proxy') || caller->isa('Pixie') ) {
    return;
  }
  else {
    $_[0]->restore;
    return ! $_[0];
  }
}

sub bool {
  if ( caller->isa('Pixie::Proxy') || caller->isa('Pixie') ) {
    return 1;
  }
  else {
    $_[0]->restore;
    return $_[0];
  }
}

sub concat_str {
  my($target, $rev) = @_[1,2];
    return $rev ? ($target . "$_[0]")  : ("$_[0]" . $target);
}

sub stringify {
  $_[0]->overload::StrVal;
}

package Pixie::Proxy::HASH::Overloaded;
our @ISA = qw/Pixie::Proxy::HASH Pixie::Proxy::Overloaded/;

package Pixie::Proxy::ARRAY::Overloaded;
our @ISA = qw/Pixie::Proxy::ARRAY Pixie::Proxy::Overloaded/;
1;
