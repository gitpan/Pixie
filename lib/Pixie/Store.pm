package Pixie::Store;

use strict;
our $VERSION = '2.04';
my %typemap = ( memory => 'Pixie::Store::Memory',
                bdb => 'Pixie::Store::BerkeleyDB',
                dbi => 'Pixie::Store::DBI', );

sub connect {
  my $proto = shift;
  my($type, $path) = split(':', shift, 2);

  $type = lc($type);
  die "Invalid database spec" unless exists $typemap{$type};

  eval "require " . $typemap{$type};
  die $@ if $@;

  $typemap{$type}->connect($path,@_);
}

# Low level locking

sub lock_object_for {}

sub unlock_object_for {}

1;

__END__

=head1 NAME

Pixie::Store -- Abstract interface to physical storage

=head1 SYNOPSIS

In a deploy script:

  use Pixie::Store::DBI;

  # Setup the datastore.
  Pixie::Store::DBI->deploy('dbi:mysql:dbname=foo',
                            user => 'wibble',
                            pass => 'plib',
                            object_table => 'object');

In a pixie client:

  use Pixie::Store::MySubclass;
  use Pixie;

  my $pixie = Pixie->connect('prefix:myspec',
                             user => 'bill',
                             pass => 'flobadob');


=head1 DESCRIPTION

Pixie::Store provides pixie with an abstracted interface to the
physical storage used to actually store the objects that Pixie
manages. It is not a 'public' class; most Pixie users will never have
to touch it except maybe to call the C<deploy> method of an
appropriate subclass.

However, if you want to add another storage medium to Pixie, start
here. (If you want to add specific methods for storing in a particular
RDBMS, you should take a look at L<DBIx::AnyDBD> before diving into
Pixie::Store::DBI::Default and its woefully underdocumented friends.

=head2 The Public Interface

There is no public interface to Pixie::Store. However, where
appropriate, Pixie::Store subclasses may implement a C<deploy> method
which should be responsible for setting up a suitable storage
structure which can be connected to later. 

=head2 The Subclassable Interface

Pixie::Store implements almost no methods itself, except for a
'connect' factory method, which takes a 'storage spec' (similar in
form to the classic DBI data source spec), works out which concrete
subclass to use for the real connection, loads it if necessary and
uses that to build a store object.

But Pixie proper depends on the following methods existing and working
as described.

=over 4

=item connect(SPEC, @ARGS)

Makes the actual connection and returns an object of the appropriate
class. The only fixed part of the interface is that the storage spec
shall come first, and the only fixed part of that is that storage
specs tend to look like 'id:...'. The 'id:' tag is used by
C<Pixie::Store::connect> to identify which subclass to
instantiate. L</The Typemap> has more details of how that works.

=item clear

Empties the datastore, removes all stored objects and any associated
metadata. Use with caution. (It is remarkably handy when one is
writing test scripts though...)

=item store_at( OID, FLATTENED_OBJECT )

Take the FLATTENED_OBJECT and stash it where it can be found via the
given OID. The FLATTENED_OBJECT is guaranteed to be an arbitrarily
long string of bytes (just to make life easy...). An OID is a string
of up to 255 characters. Overwrites any existing entry at that OID.

=item get_object_at( OID )

Returns the object associated with the given OID if it exists; returns
undef/the empty list if no object can be found and throws an exception
if it finds more than one object associated with that OID. (OIDs are
supposed to be unique after all).

=item delete( OID )

Deletes the object associated with OID. Returns true if an object
existed, or false if there was no such object.

=item lock

Possibly misnamed. Locks the database so that nobody else can
interfere. (Actually, it is often implemented as 'begin
transaction'...).

=item unlock

Again, possibly misnamed. Ensures that all the changes that have been
inserted really have been inserted, and frees the database for other
users. Should possibly be called 'commit'.

=item rollback

Rolls the database back to the state it was in at the last 'lock'. Not
misnamed. (Hurrah).

=back

=head2 The Typemap

Once you have subclassed Pixie::Store you need to let it know about
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

Copyright 2002 Fotango Ltd

This software is released under the same license as Perl itself.



