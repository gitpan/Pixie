package Pixie::Complicity;

$Pixie::Complicity::Loaded++;

=head1 NAME

Pixie::Complicity - making things play well with pixie

=head1 DESCRIPTION

Complicity: <<defintion>>

=head2 Rationale

For many objects, Pixie can and does store the object transparently
with no assistance from the object's class. However, sometimes that's
just not the case; most commonly in the case of classes that are
implemented using XS, and which store their data off in some C
structure that's inaccessible from Perl. Getting at such information
without the complicity of the class in question would require Pixie to
be, near as dammit, telepathic. And that's not going to happen any
time soon.

So, we provide a set of methods in UNIVERSAL, which are used by Pixie
in the process of storing and fetching objects. All you have to do is
override a few of them in the class in question. (Remember, even if
you're using a class from CPAN, the class's symbol table is always
open, so you can cheat and add the helper methods anyway, we've chosen
a method namespace (all methods begin with px_) which we hope doesn't
clash with any classes that are out there, in the wild.

=head2 Example

Consider the C<Set::Object> class. It's a very lovely class,
implementing a delightfully fast set, with all the set operations
you'd expect. However, in order to get the speed, it's been
implemented using XS, and the Data::Dumper visible part of it is
simply a scalar reference. So, if we want to use Set::Object in our
project (and we do), we need to make it complicit with Pixie.

So, first we make sure that Pixie knows it's storable:

    sub Set::Object::px_is_storable { 1 }

Then we think about how we're going to render the thing storable. The
only important thing about a set, for our purposes, is the list of its
members (and what do you know, Set::Object provides a C<members>
method to get at that). We'll press the 'memento' pattern into
use. The idea is that we create a memento object which will store
enough information about an object for that object to be recreated
later. We set up Set::Object's C<px_freeze> method to create that
memento:

    sub Set::Object::px_freeze {
        my $self = shift;
        return bless [ $self->members ], 'Memento::Set::Object';
    }

Easy. For our next trick, we need to provide some way for a memento to
be turned back into an object. Pixie guarantees to call C<px_thaw> on
every object that it retrieves from the data store, so, all we have to
do is implement an appropriate C<px_thaw> method I<in the memento
class>.

    sub Memento::Set::Object::px_thaw {
        my $self = shift;
        return Set::Object->new(@$self);
    }

And, as if by magic, Set::Objects can now be happily persisted within
your Pixie.

=head2 The Complicit Methods

Pixie puts a lot of methods into UNIVERSAL, because that's where the
behaviour makes the most sense. Some of these methods are useful to
override when you need to help Pixie out with object storage; others
are useful when you're writing the tools that I<use> Pixie (but we
haven't actually added many of those yet) and still others are almost
certainly never going to be overridden by client code, but we'll
document them just in case. We start with the 'storage helper' methods
that you are most likely to override:

=over 4

=item px_is_storable

A boolean method. By default, Pixie thinks only HASH and ARRAY based
objects are storable. If you have a class that you want to make
persistent, and it doesn't use one of these representations, then just
add C<sub px_is_storable { 1 }> to your class definition.

=item px_freeze

Called by Pixie on every object that it stores, C<px_freeze> transforms
an object into something a little more... storable. Remember,
px_freeze operates on the 'real' object, not a copy. Generally you
should create a new object in some memento class, dump the storable
state into it and return the memento. (Of course, if px_thaw just gets
rid of some cached computations, you might prefer to operate directly
on the object).

=item px_thaw

Called by Pixie on every object that it retrieves from the store. Use
this to turn memento objects back into the real thing.

NB: If your C<px_freeze> blesses an object into a seperate memento class
then remember to implement C<px_freeze> in the memento class, not the
source class.

=item px_is_immediate

Another boolean. Used by Pixie to know whether an object in this class
should be immediately fetched in cases where Pixie would normally use
a Pixie::Proxy object to provide deferred loading. You generally want
to use this for objects that get accessed directly (you naughty
encapsulation violator you), because a Pixie::Proxy only fetches the
real thing when it notices a method call to the object.

=item px_as_rawstruct

Returns an unblessed HASH/ARRAY/SCALAR ref which is a shallow clone of
the object in question.

Sometimes you can get away without having to write C<px_freeze> and
C<px_thaw>. Say you have a hash based object, and some of its keys
are the cached (large) results of an expensive computation, which can
be entirely derived from the 'real' instance variables. So, to strip
those out of the stored object, you could do the following:

   sub px_as_rawstruct {
       my $self = shift;
       {@$self{grep !/^cached_/, keys %$self}}
   }

Aren't hash slices lovely?

=item px_empty_new

Class method. Returns an empty object in the given class. The default
implementation of this does C<$class-E<gt>new()>. We do this so that the
class can 'know about' its instance (some classes like to initialize
various static variables etc...) but, if your class's 'new' method
doesn't cope with an empty argument list, you could override this
method. (I'm thinking of adding a 'px_post_populating_hook' method,
which would be called after pixie has populated an object. Useful for
those classes whose 'new' methods require arguments and then call an
init method to set up stuff based on the instance variables...)

=back

=cut

package UNIVERSAL;

use Scalar::Util qw/ blessed weaken reftype isweak /;
use strict;

sub px_is_storable {
  my $self = shift;

  reftype($self) =~ /^(?:HASH|ARRAY)/;
}

sub px_class {
  my $proto = shift;
  return ref($proto) || $proto
}

sub px_oid { $_[0]->PIXIE::oid };

sub px_freeze { shift }
sub px_thaw { shift }
sub px_is_immediate { }

sub px_as_rawstruct {
  my $self = shift;
  my $type = reftype($self);

  if ($type eq 'HASH') {
    return { %$self };
  }
  elsif ($type eq 'ARRAY') {
    return [ @$self ];
  }
  elsif ($type eq 'SCALAR') {
    my $scalar = $$self;
    return \$scalar;
  }
}

sub px_empty_new {
  my $proto = shift;
  $proto->new;
}

# 'Internal' methods


sub _px_extraction_freeze { Pixie->get_the_current_pixie->extraction_freeze(@_) }
sub _px_extraction_thaw   { Pixie->get_the_current_pixie->extraction_thaw(@_)   }
sub _px_insertion_freeze  { Pixie->get_the_current_pixie->insertion_freeze(@_)  }
sub _px_insertion_thaw    { Pixie->get_the_current_pixie->insertion_thaw(@_)    }

1;
