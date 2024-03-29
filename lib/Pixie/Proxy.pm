=head1 NAME

Pixie::Proxy - placeholders for real objects in a Pixie store

=head1 SYNOPSIS

  use Pixie::Proxy;

  # this only works for blessed Hashes & Arrays currently:
  my $obj   = MyObject->new
  my $proxy = Pixie::Proxy->px_make_proxy( $obj );

  # a while later, after the obj has been stored and $obj goes away...
  $obj = undef;

  $proxy->a_method;  # same as $obj->a_method, with a lot of magic

  # auto-magically loads $obj from the store, copies it into
  # $proxy, and re-blesses $proxy into the right class (MyObject)
  # before calling a_method() on it.

=head1 DESCRIPTION

C<Pixie::Proxy> lets you load objects from a Pixie store on demand.  So if
you have a tree of objects and you only need to access the root node of the
tree, you don't have to face the performance hit of loading the entire tree.

C<Pixie::Proxy> and its subclasses magically fetch the object from the store
whenever a method is called, (and if your class uses L<overload>, whenever an
overloaded operator is used).

If proxying interferes with your code, or if you simply prefer to load an
entire object heirarchy at one go, simply set the C<px_is_immediate> constant
to some true value in the classes you don't want proxied.

=cut

package Pixie::Proxy;

use strict;
use warnings::register;
require overload;

# For now we're going to assume that we can only handle hashes or
# array based objects. This may not remain the case.

use Scalar::Util qw( reftype );

use Pixie::Object;
use Pixie::FinalMethods;
use Pixie::Complicity;

use base qw( Pixie::Object );

our $AUTOLOAD;
our $VERSION = '2.08_02';

## TODO: rename 'new_proxy_for' ?
sub px_make_proxy {
  my $class         = shift;
  my($oid, $obj)    = @_;
  my $proxied_class = ref($obj);
  my $real_class    = 'Pixie::Proxy::' . reftype($obj);

  ## TODO: check for / auto load existing subclass here?
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
  my $self  = shift;
  my $pixie = shift;
  my $oid   = $self->_oid;
  $pixie->get_with_strategy($oid, $self->px_lock_strategy);
}

sub isa {
  my $self   = shift;
  my($class) = @_;
  $self->UNIVERSAL::isa($class) || ref($self) && $self->px_class->isa($class);
}

sub can {
  my $self    = shift;
  my($method) = @_;

  $self->UNIVERSAL::can($method) ||
      ref($self) && $self->px_restore->can($method);
}

#-----------------------------------------------------------------------------
# Storable compat methods

#
# We serialize into the form:
#     $oid => [ $original_class ]
#

sub STORABLE_freeze {
  my $self    = shift;
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

#-----------------------------------------------------------------------------
# Pixie Complicity methods

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
  my $self  = shift;
  # TODO: fix cut-n-paste error below (get_the_current_pixie takes no args),
  #       and use $pixie hereafter
  my $pixie = Pixie->get_the_current_pixie($self->_oid);
  my $obj   = Pixie->get_the_current_pixie->cache_get($self->_oid);

  if ( defined $obj ) {
    bless $self, 'Class::Whitehole';
    $pixie->forget_about($self);
    return $obj;
  }

  $self->px_lock_strategy( $pixie->get_the_current_lock_strategy ||
                           $pixie->lock_strategy );

  if ($self->px_class->px_is_immediate) {
    my $oid = $self->_oid;
    bless $self, 'Class::Whitehole';
    Pixie->get_the_current_pixie->_get($oid);
    # TODO: add $obj to the cache?
  }
  else {
    $self->px_the_store($pixie);
    $pixie->cache_insert($self);
    return $self;
  }
}

#-----------------------------------------------------------------------------
# Subclass methods

sub px_the_store { $_[0]->subclass_responsibility(@_) }


#-----------------------------------------------------------------------------
# other methods

sub DESTROY {
  my $self = shift;
  local $@ = $@;
  return unless ref $self;
  my $store = $self->px_the_store;
  $store->forget_about( $self ) if (defined $store);
}

sub AUTOLOAD {
  my $method = $AUTOLOAD;
  $method    =~ s/.*:://;
  $_[0]->px_restore->$method(@_[ 1 .. $#_ ]);
}

#-----------------------------------------------------------------------------
# Embedded subclasses

package Pixie::Proxy::ARRAY;

use base 'Pixie::Proxy';

sub new {
  my $class = shift;
  return bless [], $class;
}

## TODO: use constants for array indecies?
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

## TODO: write px_oid()

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

## TODO: rename 'px_the_current_pixie'
## TODO: hide with Scalar::Footnote?
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

sub px_lock_strategy {
  my $self = shift;
  if (@_) {
    $self->[3] = shift;
    return $self;
  }
  else {
    return $self->[3];
  }
}


#-----------------------------------------------------------------------------
package Pixie::Proxy::HASH;

use base 'Pixie::Proxy';

sub new {
  my $class = shift;
  return bless {}, $class;
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
    ## TODO: check reftype eq 'HASH' & improve warning here
    unless (ref($self)) {
      require Carp;
      Carp::confess "Invalid thing: $self";
    }
    return $self->{class};
  }
}

## TODO: rename 'px_populate_from'
sub populate_from {
  # TODO: try more efficient %{$_[0]} = ();
  foreach my $key (keys %{$_[0]}) {
    delete $_[0]->{$key};
  }
  %{$_[0]} = %{$_[1]};
  return $_[0];
}

## TODO: rename 'px_the_current_pixie'
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

## TODO: should this return $self as ARRAY does?
sub px_clear_the_store {
  my $self = shift;
  delete $self->{_the_store};
}

sub px_lock_strategy {
  my $self = shift;
  if (@_) {
    $self->{_lock_strategy} = shift;
    return $self;
  }
  else {
    return $self->{_lock_strategy};
  }
}

#-----------------------------------------------------------------------------
package Pixie::Proxy::Overloaded;

##
## TODO: should we check if the caller is Pixie all the time?
## TODO: do we need to consider the de-referencing operators?
##

my %FALLBACK = (
		'!'    => \&bool_not,
		'.'    => \&concat_str,
		'""'   => \&stringify,
		'bool' => \&bool,
	       );

## TODO: pull this out into a separate sub & break it down
use overload
    fallback => 0,
    nomethod => sub {
      no strict 'refs';
      my $method = pop;
      my $class  = $_[0]->px_class;

      # TODO: this uses private overload.pm methods, so will break if they
      # change. Would be good to patch overload.pm so they become part of the
      # public API.

      # TODO: replace this with overload::Overloaded( $class ) ?
      # when you "use overload fallback => $x" you can access $x like this:
      my $fallback = $ {$class . "::()"};

      # this finds the overloaded method of the original class if it exists.
      if ( my $sub = overload::ov_method( overload::mycan($class, "\($method"), $class) ) {
        $_[0]->px_restore;
        &$sub;
      }

      # does this respect rules for "magic autogeneration" ?
      # it looks like similar logic (see overload docs)
      elsif (!defined($fallback) || $fallback) {
        # Try falling back
        push @_, $fallback;
        if (exists $FALLBACK{$method}) {
          goto &{$FALLBACK{$method}}
        }
        else {
	  # TODO: this tries to behave like overload.pm, but fails when
	  #       $fallback is true. Then, how to mimick the correct behaviour?
	  #       Best let overload internals do this.
	  # TODO: carp ...
          die "No Fallback found for $method";
        }
      }
      # TODO: isn't this just "defined($fallback)" ?
      elsif (defined $ {$class . "::()"}) {
        $_[0]->can('nomethod')->(@_, $method);
      }
      else {
        require Carp;
        Carp::confess "Can't find overloaded method for $method";
      }
    };

## TODO: factor out a sub: is_caller_pixie( caller )
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

__END__

=head1 AUTHORS

Piers Cawley <pdcawley@bofh.org.uk> - code

Steve Purkis <spurkis@cpan.org> - docs

=head1 SEE ALSO

L<Pixie>, L<Pixie::Complicity>

=cut
