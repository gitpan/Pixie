=head1 NAME

Pixie::Store -- Factory & abstract base class for Pixie stores

=head1 SYNOPSIS

  # you should never have to use this class directly!

  use Pixie;
  Pixie->deploy( $dsn, %args );
  my $px = Pixie->connect( $dsn, %args );

=head1 DESCRIPTION

Pixie::Store provides Pixie with an abstract interface to the physical storage
used to actually store the objects that Pixie manages. It is not a 'public'
class; most Pixie users will never have to touch it.

However, if you want to add another storage medium to Pixie, start here. (If
you want to add specific methods for storing in a particular RDBMS, you should
take a look at L<DBIx::AnyDBD> before diving into L<Pixie::Store::DBI> and its
woefully underdocumented friends.

=cut

package Pixie::Store;

use strict;
use warnings;

use Carp qw( confess );
use Scalar::Util qw( weaken );

use Pixie::Name;
use Pixie::ObjectGraph;
use Pixie::FinalMethods;

use base qw( Pixie::Object );

our $VERSION = "2.08_02";
our %typemap = ( memory => 'Pixie::Store::Memory',
		 bdb    => 'Pixie::Store::BerkeleyDB',
		 dbi    => 'Pixie::Store::DBI', );

#use overload
#  '""' => 'as_string';

#------------------------------------------------------------------------------
# Class methods

sub deploy {
  my $class = shift;
  return $class->subclass_responsibility( @_ ) if ref( $class );
  return $class->_deploy( @_ );
}

sub connect {
  my $class = shift;
  return $class->subclass_responsibility( @_ ) if ref( $class );
  return $class->_connect( @_ );
}

sub _deploy {
  my $class = shift;
  my $spec  = shift;

  my ($type, $path) = $class->get_type_and_path( $spec );
  my $type_class    = $class->load_store_type( $type );

  return $type_class->deploy( $path, @_ );
}

sub _connect {
  my $class = shift;
  my $spec  = shift;

  my ($type, $path) = $class->get_type_and_path( $spec );
  my $type_class    = $class->load_store_type( $type );

  my $self = $type_class->connect( $path, @_ );
  $self->{spec} = $spec;	# TODO: use accessor for this

  return $self;
}

sub get_type_and_path {
  my $class = shift;
  my $spec  = shift;
  return split(':', $spec, 2);
}

sub load_store_type {
  my $class = shift;
  my $type  = shift;

  confess( "Invalid store type: '$type'" ) unless exists $typemap{$type};

  eval "require " . $typemap{$type};
  confess( "Error loading $typemap{$type}: $@" ) if $@;

  return $typemap{$type};
}

sub as_string {
  my $class = shift;
  my $str   = '';

  if (ref $class) {
    $str .= ref($class);
    $str .= ": $class->{spec}" if $class->{spec};
  } else {
    $str .= $class;
  }

  return $str;
}


#------------------------------------------------------------------------------
# Instance methods

sub clear               { $_[0]->subclass_responsibility(@_) }
sub store_at            { $_[0]->subclass_responsibility(@_) }
sub get_object_at       { $_[0]->subclass_responsibility(@_) }
sub delete              { $_[0]->subclass_responsibility(@_) } # TODO: not used?
sub _delete             { $_[0]->subclass_responsibility(@_) }
sub remove              { $_[0]->subclass_responsibility(@_) } # TODO: not used?
sub rootset             { $_[0]->subclass_responsibility(@_) }
sub _add_to_rootset     { $_[0]->subclass_responsibility(@_) }
sub remove_from_rootset { $_[0]->subclass_responsibility(@_) }
sub lock                { $_[0]->subclass_responsibility(@_) }
sub unlock              { $_[0]->subclass_responsibility(@_) }
sub rollback            { $_[0]->subclass_responsibility(@_) }

## TODO: use a name that's impossible for others to trample over
##       best idea is to move this into Pixie::Name->object_graph
sub object_graph_for {
  my $self  = shift;
  my $pixie = shift;

  my $graph = $pixie->get_object_named('PIXIE::Node Graph');
  unless ($graph) {
    $graph = Pixie::ObjectGraph->new;
    $pixie->bind_name('PIXIE::Node Graph' => $graph);
  }

  return $graph;
}

sub remove_from_store {
  my $self = shift;
  my $oid  = shift;

  $self->remove_from_rootset($oid)
       ->_delete($oid);
}

# Low level locking
# $locker is usually a Pixie

sub locked_set {
    my $self = shift;
    return $self->{locked_set} ||= {};
}

sub lock_object_for {
    my $self = shift;
    my($oid, $locker) = @_;
    $self->locked_set->{ $oid } = $locker->_oid;
    return 1;
}

sub unlock_object_for {
    my $self = shift;
    my $oid  = shift;
    delete $self->locked_set->{$oid};
}

sub release_all_locks {
    my $self = shift;
    my $locked_set = $self->locked_set;
    $self->unlock_object_for(@$_)
        for map {[$_ => $locked_set->{$_}]}
            keys %$locked_set;
    return $self;
}

sub add_to_rootset {
  my $self  = shift;
  my $thing = shift;
  # TODO: get the oid out here?
  $self->_add_to_rootset($thing) unless $self->is_hidden($thing);
}

## TODO: use names that are impossible for others to trample over
##       best idea is to move this into Pixie::Name
sub is_hidden {
  my $self  = shift;
  my $thing = shift;
  $thing->PIXIE::oid =~ /^<NAME:PIXIE::/;
}

sub lock_for_GC {
  my $self = shift;
  $self->lock;
}

sub unlock_after_GC {
  my $self = shift;
  $self->unlock;
}

sub DESTROY {
    my $self = shift;
    $self->release_all_locks;
}

1;

__END__

=head1 The Public Interface

There is no public interface to C<Pixie::Store>.  You should be able to get by
with L<Pixie::deploy()> and L<Pixie::connect()> for all your storage needs.

=head2 Data Source Names (Storage Specs)

Pixie's C<Data Source Names> (or C<Storage Specs>) are typically similar in
form to the classic DBI data source spec. But the only fixed part of a Pixie
DSN is that the storage type comes first:

    type:path

The DSN's I<type> is used by C<Pixie::Store> to identify which subclass to use.
L</The Typemap> details which class to use for each I<type>.

=head2 CLASS METHODS

C<Pixie::Store> operates as a factory/dispatch class when using the class
methods below.  Subclasses are loaded as needed, and L</The Typemap> is used to
determine which class to dispatch the request to.

=over 4

=item $class = Pixie::Store->deploy( $dsn [, @ARGS] )

Deploys the Pixie store specified.  Loads the $dsn's class on demand (see
L</The Typemap>).  Dies on error.

B<Note:> This will likely change to return a new, connected store object.

=item $store = Pixie::Store->connect( $dsn [, @ARGS] )

Connect to the Pixie store specified.  Loads the $dsn's class on demand (see
L</The Typemap>).  Returns a new store object of the appropriate class.  Dies
on error.

=back

=head1 The Subclassable Interface

L<Pixie::Store> operates as an abstract base class for Pixie stores to inherit
from.  L<Pixie> depends on the following methods existing and working as
described.

=head2 INSTANCE METHODS

=over 4

=item $class = $class->deploy( $dsn [, @ARGS] )

Deploy the Pixie store specified.  Returns this class, or dies on error.

B<Note:> This will likely change to return a new, connected store object.

=item $store = $class->connect( $dsn [, @ARGS] )

Connect to the Pixie store specified.  Returns a new Pixie::Store object, or
dies on error.

=item $store = $store->clear()

Empties the datastore, removes all stored objects and any associated metadata.
Use with caution. (It is remarkably handy when one is writing test scripts
though...)

=item $store->store_at( $OID, $FLATTENED_OBJECT )

Take the FLATTENED_OBJECT and stash it where it can be found via the
given OID. The FLATTENED_OBJECT is guaranteed to be an arbitrarily
long string of bytes (just to make life easy...). An OID is a string
of up to 255 characters. Overwrites any existing entry at that OID.

Currently returns an array containing the OID and FLATTENED_OBJECT,
though this may change in the future.

B<Note:> looks like this takes an OBJECT rather than a FLATTENED_OBJECT;
flattening is done here.  Also, a LOCKING_STRATEGY is sometimes passed in.

=item $obj = $store->get_object_at( $OID )

Returns the object associated with the given OID if it exists; returns
undef/the empty list if no object can be found and throws an exception
if it finds more than one object associated with that OID. (OIDs are
supposed to be unique after all).

=item $bool = $store->delete( $OID )

Deletes the object associated with OID. Returns true if an object
existed, or false if there was no such object.

B<Note:> looks like this is actually implemented as C<_delete()>.

=item $store->lock()

Possibly misnamed. Locks the database so that nobody else can interfere.

B<Note:> often implemented as C<begin_transaction()>...

=item $store->unlock()

Again, possibly misnamed. Ensures that all the changes that have been
inserted really have been inserted, and frees the database for other
users. Should possibly be called 'commit'.

=item $store->rollback()

Rolls the database back to the state it was in at the last 'lock'. Not
misnamed. (Hurrah).

=back

=head2 Note

Note that B<there are other methods you must override that are not yet
documented here>.  You should read through the source before you attempt
to write a subclass.

=head2 The Typemap

Once you have subclassed C<Pixie::Store> you need to let it know about
your new subclass so it can make C<connect> work. To do that, pick an
appropriate prefix string to identify your subclass and add something
like the following -- after the C<use base 'Pixie::Store';>
part, or things will break -- to your code:

  $Pixie::Store::typemap{prefix} = __PACKAGE__;

Once you have done this, the code given in the synopsis should work,
as if by magic.

=head1 AUTHORS

James Duncan <james@fotango.com>, Piers Cawley <pdcawley@bofh.org.uk>
and Leon Brocard <acme@astray.com>.

=head1 COPYRIGHT

Copyright 2002-2004 Fotango Ltd

This software is released under the same license as Perl itself.

=cut

