package Pixie::Proxy;

use strict;
use warnings::register;
require overload;

# For now we're going to assume that we can only handle hashes or
# array based objects. This may not remain the case.


use Scalar::Util qw/reftype/;

our $AUTOLOAD;

our $VERSION='2.05';

use Pixie::Object;
use Pixie::FinalMethods;
use Pixie::Complicity;
use base 'Pixie::Object';

sub px_make_proxy {
  my $self = shift;
  my($oid, $obj) = @_;
  my $proxied_class = ref($obj);
  my $real_class = 'Pixie::Proxy::' . reftype($obj);

  $real_class .= '::Overloaded' if overload::Overloaded($proxied_class);
  $real_class->new->_oid($oid)
                  ->px_class($proxied_class);
}

sub px_restore {
  my $class = $_[0]->px_class;
  my $pixie = $_[0]->px_the_store;
  $_[0]->px_clear_the_store;
  my $real_obj = $_[0]->px_fetch_from($pixie);
  return $_[0] = undef unless defined $real_obj;
  $_[0]->populate_from($real_obj);
  bless $real_obj, 'Class::Whitehole';
  my $ret = bless $_[0], $class;
}

sub px_fetch_from {
  my $self = shift;
  my $pixie = shift;

  my $oid = $self->_oid;

  $pixie->get_with_strategy($oid,
			    $pixie->lock_strategy_for($oid));
}

sub isa {
  my $self = shift;
  my($class) = @_;
  $self->UNIVERSAL::isa($class) || ref($self) && $self->px_class->isa($class);
}

sub can {
  my $self = shift;
  my($method) = @_;

  $self->UNIVERSAL::can($method) ||
      ref($self) && $self->px_restore->can($method);
}


sub STORABLE_freeze {
  my $self = shift;
  my $cloning = shift;
  return if $cloning;

  return $self->_oid, [$self->px_class];
}

sub STORABLE_thaw {
  my($target, $cloning, $oid, $class) = @_;
  return if $cloning;
  $target->_oid($oid);
  $target->px_class($class->[0]);
  return $target;
}

sub _px_insertion_thaw {
  my $self = shift;
  $self->px_the_store(Pixie->get_the_current_pixie);
  return $self;
}

sub _px_insertion_freeze {
  my $self = shift;
  my $dupe = ref($self)->new->_oid($self->_oid)
                            ->px_class($self->px_class);
}



sub _px_extraction_thaw {
  my $self = shift;
  my $pixie = Pixie->get_the_current_pixie($self->_oid);
  my $ret = Pixie->get_the_current_pixie->cache_get($self->_oid);
  if ( defined $ret ) {
    bless $self, 'Class::Whitehole';
    $pixie->forget_about($self);
    return $ret;
  }

  $pixie->lock_strategy_for($self,
			    Pixie->get_the_current_lock_strategy);

  if ($self->px_class->px_is_immediate) {
    my $oid = $self->_oid;
    bless $self, 'Class::Whitehole';
    Pixie->get_the_current_pixie->_get($oid);
  }
  else {
    $self->px_the_store($pixie);
    $pixie->cache_insert($self);
    return $self;
  }
}

sub DESTROY {
  my $self = shift;
  local $@ = $@;
  return unless ref $self;
  my $store = $self->px_the_store;
  if (defined $store) {
    $store->forget_about($self);
  }
}

sub AUTOLOAD {
  my $method = $AUTOLOAD;
  $method =~ s/.*:://;
  $_[0]->px_restore->$method(@_[1..$#_]);
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

sub px_class {
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

sub px_the_store {
  my $self = shift;
  if (@_) {
    $self->[2] = shift;
    return $self;
  }
  else {
    return $self->[2];
  }
}

sub px_clear_the_store {
  my $self = shift;
  $self->[2] = undef;
  return $self;
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


sub px_oid { $_[0]->_oid }

sub px_class {
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

sub px_the_store {
  my $self = shift;
  if (@_) {
    $self->{_the_store} = shift;
    return $self;
  }
  else {
    return $self->{_the_store};
  }
}

sub px_clear_the_store {
  my $self = shift;
  delete $self->{_the_store};
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
      my $class = $_[0]->px_class;
      my $fb = $ {$class . "::()"};
      if ( my $sub = overload::ov_method( overload::mycan($class, "\($method"), $class) ) {
        $_[0]->px_restore;
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
    $_[0]->px_restore;
    return ! $_[0];
  }
}

sub bool {
  if ( caller->isa('Pixie::Proxy') || caller->isa('Pixie') ) {
    return 1;
  }
  else {
    $_[0]->px_restore;
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
