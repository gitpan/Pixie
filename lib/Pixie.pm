=head1 NAME

Pixie - The magic data pixie

=head1 SYNOPSIS

  use Pixie;

  my $pixie = Pixie->new->connect( 'memory' );
  my $obj   = SomeObject->new;

  # Note: this API will be changing! See below for details.

  # Store an object
  my $cookie = $pixie->insert( $obj );

  undef( $obj );

  # Fetch it back
  my $obj = $pixie->get( $cookie );

  # Give it a name
  $pixie->bind_name( "Some Name" => $obj );
  my $obj2 = $pixie->get_object_named( "Some Name" );

  # Delete it
  $pixie->delete( $cookie ) || warn "eek!";

  # some stores need deploying before you can use them:
  $pixie = Pixie->deploy( 'dbi:mysql:dbname=px_test' );

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

The inserted object is a blessed hash.

=item *

The inserted object is a blessed array

=item *

The inserted object is 'complicit' with Pixie, see L<Pixie::Complicity>

=back

You'll note that we don't  include 'blessed arbitrary scalars' in this
list. This is because, during testing we found that the majority of
objects that are represented as blessed scalars are often using XS to
store extra data that Storable and Data::Dumper can't see, which leads
to all sorts of problems later. So, if you use a blessed scalar as
your object representation then you'll have to use the complicity
features. Sorry.

Pixie can additionally be used to name objects in the store, and fetch them
later on with that name.

=cut

package Pixie;

use strict;
use warnings::register;

use Carp qw( carp confess );

use Data::UUID;
use Scalar::Util qw( blessed reftype isweak );
use Pixie::Proxy;
use Data::Dumper;

use Pixie::Store;
use Pixie::ObjectInfo;
use Pixie::ObjectGraph;

use Pixie::LiveObjectManager;
use Pixie::Complicity;

use Pixie::LockStrat::Null;

use base qw( Pixie::Object );

our $VERSION = "2.08_02";
our $the_current_pixie;
our $the_current_oid;
our $the_current_lock_strategy;
our $the_current_object_graph;

#use overload
#  '""' => 'as_string';

#BEGIN { $Data::Dumper::Useperl = 1 }

#------------------------------------------------------------------------------
# Class methods
#------------------------------------------------------------------------------

sub get_the_current_pixie {
  my $class = shift;
  return $the_current_pixie;
}

sub get_the_current_oid {
  my $class = shift;
  return $the_current_oid;
}

sub get_the_current_lock_strategy {
  return $the_current_lock_strategy;
}

sub get_the_current_object_graph {
  return $the_current_object_graph;
}

## TODO: return new object
sub deploy {
  my $class = shift;
  Pixie::Store->deploy( @_ );
  return $class;
}

#------------------------------------------------------------------------------
# Instance methods
#------------------------------------------------------------------------------

sub init {
  my $self = shift;
  $self->connect('memory');
  $self->{_objectmanager} = Pixie::LiveObjectManager->new->set_pixie($self);
  return $self;
}

sub connect {
  my $self = shift;
  $self = $self->new unless blessed( $self );
  $self->store( Pixie::Store->connect(@_) );
}

sub clear_storage {
  my $self = shift;
  $self->store->clear;
}

#------------------------------------------------------------------------------
# accessor-kinda methods

sub _oid {
  my $self = shift;
  $self->{_oid} ||= do {
    require Data::UUID;
    Data::UUID->new()->create_str();
  }
}

## TODO: rename to _store or the_store
sub store {
  my $self = shift;
  if (@_) {
    $self->{store} = shift;
    return $self;
  } else {
    return $self->{store};
  }
}

sub clear_store {
    my $self       = shift;
    $self->{store} = undef;
    return $self;
}

sub lock_strategy {
  my $self = shift;
  if (@_) {
    $self->{lock_strategy} = shift;
    $self;
  }
  else {
    $self->{lock_strategy} ||= Pixie::LockStrat::Null->new;
  }
}

## basically an accessor for live obj manager...
sub lock_strategy_for {
  my $self       = shift;
  my $obj_or_oid = shift;

  if (@_) {
    $self->{_objectmanager}->lock_strategy_for($obj_or_oid, @_);
    return $self;
  }
  else {
    return $self->{_objectmanager}->lock_strategy_for($obj_or_oid);
  }
}

#------------------------------------------------------------------------------
# storage methods

## TODO: is this actually being used?
sub store_individual {
  my $self = shift;
  my $real = shift;

  confess( "Can't store a Pixie::ObjectInfo" )
    if eval { $real->isa('Pixie::ObjectInfo') };

  my $oid = $real->PIXIE::oid;
  if (defined $oid) {
    $self->store_individual_at($real, $oid);
  }
  else {
    # TODO: when are we *not* gonna have an oid?  Should die really.
    return $real;
  }
}

## TODO: fix order of params: everywhere else uses oid => obj.
sub store_individual_at {
  my $self = shift;
  my($obj, $oid, $strategy) = @_;
  $strategy ||= $self->lock_strategy;
  # TODO: is %Pixie::Stored actually used?
  if ($Pixie::Stored{$oid}) {
    return $Pixie::Stored{$oid};
  }
  else {
    return Pixie::Proxy->
      px_make_proxy( $self->store->store_at($oid, $obj, $strategy) );
  }
}

#------------------------------------------------------------------------------
# Insert methods

sub insert {
  my $self  = shift;
  my $graph = Pixie::ObjectGraph->new;

  my $ret = eval {
    local $the_current_object_graph = $graph;
    $self->_insert(@_)
  };
  $self->bail_out($@) if $@;

  $self->_insert($self->object_graph->add_graph($graph))
    unless $_[0]->isa('Pixie::ObjectGraph');
  $self->add_to_rootset(@_);

  return $ret;
}

##
# How Object Freezing Works
#
# To insert a tree of objects without disturbing the original objects
# themselves we need to take a deep copy of the tree and extract each object
# to be stored individualy.
#
# We use Data::Dumper to do this, by dumping to a string, and eval'ing it
# straight away to get the new object tree.  We use Dumper's call-back hooks
# Freezer & Toaster, which are used for each object in the tree.
#
# When an object is frozen it's wrapped in an Object Holder so we can preserve
# its oid.
#
# When an object is thawed we take it out of the Holder and store it.
##

sub _insert {
  my $self = shift;
  my $this = shift;

  local %Pixie::Stored; # TODO: is %Pixie::Stored actually used?
  local $Data::Dumper::Freezer = '_px_insertion_freeze';
  local $Data::Dumper::Toaster = '_px_insertion_thaw';

  local %PIXIE::freeze_cache;
  my $proxy = $self->do_dump_and_eval($this, 1);

  return defined($proxy) ? $proxy->_oid : undef;
}

## TODO: rename deep_copy_using_data_dumper()
sub do_dump_and_eval {
  my $self = shift;
  my($thing, $do_lock) = @_;

  local $Data::Dumper::Deepcopy = 1;
  local $the_current_pixie      = $self;

  my $data_string;
  {
    my $dump_warn;
    local $SIG{__WARN__} = sub { $dump_warn ||= join '', @_ };
    # HACK: sometimes dumper fails dumping ObjectGraphs
    # doing this twice reduces the probability of getting a 0-length string
    $data_string   = Dumper($thing);
    $data_string ||= Dumper($thing);
    die $dump_warn if $dump_warn;
    die "Something went wrong with the Dump" unless length($data_string);
  }

  my $VAR1;
  $self->lock_store if $do_lock;
  eval $data_string;
  die $@ if $@;
  $self->unlock_store if $do_lock;

  return $VAR1;
}

## TODO: split up into smaller methods with better names
sub insertion_freeze {
  my $self  = shift;
  my $thing = shift;

  $self->ensure_storability($thing);
  my $oid = $thing->PIXIE::oid;

  return $PIXIE::freeze_cache{$oid} if defined $PIXIE::freeze_cache{$oid};

  $self->cache_insert($thing);
  $thing = $thing->px_freeze;

  my $obj_holder = bless( {oid     => $oid,
			   class   => blessed( $thing ),
			   content => $thing->px_as_rawstruct },
			  'Pixie::ObjHolder' );
  $PIXIE::freeze_cache{$oid} = $obj_holder;

  return $obj_holder;
}

## TODO: split up into smaller methods with better names
sub insertion_thaw {
  my $self       = shift;
  my $obj_holder = shift;
  die "Object is not a Pixie::ObjHolder" unless $obj_holder->isa('Pixie::ObjHolder');

  my $thing     = bless $obj_holder->{content}, $obj_holder->{class};
  my $thing_oid = $obj_holder->{oid};

  $self->{_objectmanager}->bind_object_to_oid($thing, $thing_oid);
  # TODO: this has already been ensured in insertion_freeze:
  $self->ensure_storability($thing);
  my $retval = $self->store_individual_at($thing, $obj_holder->{oid});

  # Set up GC stuff
  if (my $graph = Pixie->get_the_current_object_graph) {
    $graph->add_edge($thing_oid => $_) for
      $self->proxied_content($obj_holder);
  }
  bless $thing, 'Class::Whitehole';

  return $retval;
}

sub proxied_content {
  my $self       = shift;
  my $obj_holder = shift;

  local %Pixie::neighbours;

  # Turn off deepcopy or things get *very* slow.
  local $Data::Dumper::Deepcopy = 0;
  local $Data::Dumper::Freezer  = 'Pixie::proxy_finder';
  local $Data::Dumper::Toaster  = undef;
  Data::Dumper::DumperX($obj_holder);
  return keys %Pixie::neighbours;
}

sub proxy_finder {
  my $obj = shift;
  $Pixie::neighbours{$obj->_oid} = 1 if blessed( $obj )->isa( 'Pixie::Proxy' );
  return $obj;
}

#------------------------------------------------------------------------------
# Get methods

sub get {
  my $self = shift;
  my($oid) = @_;
  $self->get_with_strategy($oid, $self->lock_strategy);
}

sub get_with_strategy {
  my $self = shift;
  my($oid, $strategy) = @_;

  $strategy ||= do {
    carp "Called with blank strategy";
    $self->lock_strategy;
  };

  local $the_current_lock_strategy = $strategy;

  $self->lock_store;
  $strategy->pre_get($oid, $self);
  my $res = eval {$self->_get($oid)};
  my $err = $@;
  $strategy->post_get($oid, $self);
  $self->bail_out($err) if $err;
  $self->unlock_store;

  return $res;
}

sub _get {
  my $self = shift;
  my $oid  = shift;

  return undef unless defined $oid;
  my $cached_struct = $self->cache_get($oid);
  return $cached_struct if defined($cached_struct)
                             && ! $cached_struct->isa('Pixie::Object');

  local $Data::Dumper::Freezer = '_px_extraction_freeze';
  local $Data::Dumper::Toaster = '_px_extraction_thaw';
  local $the_current_oid = $oid;

  my $rawstruct = $self->store->get_object_at( $oid );
  return unless defined($rawstruct);

  my $newstruct = $self->do_dump_and_eval($rawstruct);
  bless $rawstruct, 'Class::Whitehole';
  return scalar $self->cache_insert($newstruct);
}

sub extraction_freeze {
  my $self  = shift;
  my $thing = shift;
  return $thing;
}

sub extraction_thaw {
  my $self  = shift;
  my $thing = shift;
  my $oid   = Pixie->get_the_current_oid;

  $thing = $thing->px_thaw;

  # this usually calls 'make_new_object':
  my $real_obj = $thing->px_do_final_restoration;

  bless( $thing, 'Class::Whitehole' )
    unless $thing->PIXIE::address == $real_obj->PIXIE::address;

  $self->{_objectmanager}->bind_object_to_oid($real_obj => $oid);
  $real_obj->PIXIE::oid eq $oid or die "Bad OID stuff";
  $self->cache_insert($real_obj);

  return $real_obj;
}

sub make_new_object {
  my $self = shift;
  my($struct, $class) = @_;

  my $real = eval { $class->px_empty_new };
  if ($@) {
    $real = bless $struct, $class;
  }
  else {
    my $type = reftype($struct);

    if ($type eq 'SCALAR') {
      $$real = $$struct;
    }
    elsif ($type eq 'ARRAY') {
      @$real = @$struct;
    }
    elsif ($type eq 'HASH') {
      %$real = %$struct;
    }
    else {
      return $struct;
    }
  }
  return $real;
}

sub bail_out {
  my $self = shift;
  $self->rollback_store;
  $self->unlock_store;
  die @_;
}

sub delete {
  my $self       = shift;
  my $obj_or_oid = shift;
  my $oid        = blessed( $obj_or_oid ) ? $obj_or_oid->PIXIE::oid : $obj_or_oid;
  $self->cache_delete($oid);
  $self->store->remove_from_store($oid);
}

sub forget_about {
  my $self = shift;
  return unless blessed( $self );
  my $obj = shift;
  $obj->PIXIE::set_info(undef);
}

sub manages_object {
  my $self = shift;
  my($obj) = @_;

  $self->_oid eq $obj->PIXIE::get_info->pixie_id;
}

#------------------------------------------------------------------------------
# Caching related methods

sub cache_insert {
  my $self = shift;
  $self->{_objectmanager}->cache_insert(@_);
}

sub cache_size {
  my $self = shift;
  $self->{_objectmanager}->cache_size;
}

sub cache_get {
  my $self = shift;
  return undef unless defined $self->{_objectmanager};
  $self->{_objectmanager}->cache_get(@_);
}

sub cache_delete {
  my $self = shift;
  $self->{_objectmanager}->cache_delete(@_) if defined $self->{_objectmanager};
}

sub get_cached_keys {
  my $self = shift;
  $self->{_objectmanager}->cache_keys;
}

#------------------------------------------------------------------------------
# The naming section

## TODO: just use Pixie::Name by default.
sub bind_name {
  my $self = shift;
  my($name, @objects) = @_;

  require Pixie::Name;
  Pixie::Name->name_object_in($name, \@objects, $self);
}

sub unbind_name {
  my $self  = shift;
  my($name) = @_;

  require Pixie::Name;
  Pixie::Name->remove_name_from($name, $self);
}

sub get_object_named {
  my $self = shift;
  my($name, $strategy) = @_;
  require Pixie::Name;
  Pixie::Name->get_object_from($name, $self, $strategy);
}


#------------------------------------------------------------------------------
# Garbage Collection & related

sub rootset {
  my $self = shift;
  $self->{store}->rootset;
}

sub add_to_rootset {
  my $self = shift;
  $self->store->add_to_rootset($_) for grep $_->px_in_rootset, @_ ;
  return $self;
}

sub neighbours {
  my $self = shift;
  my $oid  = shift;
  $self->object_graph->neighbours($oid);
}

sub run_GC {
  my $self = shift;
  $self->store->lock_for_GC;
  my %live = map { $_ => 1 } $self->live_set;
  for ($self->working_set) {
    $self->delete($_) unless $live{$_};
  }
  $self->store->unlock_after_GC;
  return $self;
}

sub live_set {
  my $self  = shift;
  my $graph = $self->object_graph;
  my %seen  = ();
  my @nodes_to_process = $self->rootset;

  while (@nodes_to_process) {
    my $node = pop @nodes_to_process;
    next if $seen{$node};
    $seen{$node} = 1;
    push @nodes_to_process, $graph->neighbours($node);
  }

  return keys %seen;
}

sub object_graph {
  my $self = shift;
  $self->store->object_graph_for( $self );
}

sub working_set {
  my $self = shift;
  $self->store->working_set_for( $self );
}

sub ensure_storability {
  my $self = shift;
  my $obj  = shift;
  $obj->px_is_storable or die "Pixie cannot store a ", blessed( $obj );
}

#------------------------------------------------------------------------------
# Locking methods

sub lock_store     { $_[0]->store->lock; }
sub unlock_store   { $_[0]->store->unlock; }
sub rollback_store { $_[0]->store->rollback; }

sub lock_object {
  my $self = shift;
  $self->{_objectmanager}->lock_object(@_);
}

sub unlock_object {
  my $self = shift;
  $self->{_objectmanager}->unlock_object(@_);
}

#------------------------------------------------------------------------------
# Pixie::Complicity methods

sub px_freeze {
  my $self = shift;
  return bless {}, blessed( $self );
}

sub _px_extraction_thaw {
  my $self = shift;
  $self->get_the_current_pixie;
}

#------------------------------------------------------------------------------
# Miscellaneous methods

sub DESTROY {
  my $self = shift;
  $self->store->release_all_locks if defined $self->store;
  delete $self->{_objectmanager};
}

sub as_string {
  my $self = shift;
  my $str  = blessed( $self ) . ": " . $self->_oid . "\n";
  $str    .= "   " . $self->store->as_string . "\n" if $self->store;
}

1;

__END__

=head1 AVAILABLE STORE TYPES

At the time of writing the following stores were available:

=over 4

=item Memory

Simple memory store, good for testing.  See L<Pixie::Store::Memory>.

  $pixie->connect( 'memory' );

=item Berkeley DB

A Berkeley DB store, also good for testing (especially if you want to store
values across tests).  See L<Pixie::Store::BerkeleyDB>.

  $pixie->connect( "bdb:$path_to_dbfile" );

=item DBI

DBI-based stores are good for production.  See L<Pixie::Store::DBI> and
subclasses, and L<DBI> for details on DSN specs to use.

In general:

  $pixie->connect( $dbi_spec, %args );

For example:

  $pixie->connect( "dbi:SQLite:dbname=$path_to_dbfile" );
  $pixie->connect( 'dbi:mysql:dbname=test', user => 'foo', pass => 'bar' );
  $pixie->connect( 'dbi:Pg:dbname=test;user=foo;pass=bar' );

=back

See L<Pixie::Store> and its sub-classes for more details on the available types
of stores and the DSN's to use.

=head1 CONSTRUCTOR

=over 4

=item $px = Pixie->new

Create a new Pixie.  You'll have to L<connect()> to a data store before you can
really do anything.

=back

=head1 METHODS

=over 4

=item $px->deploy( $dsn [, @args ] )

Deploy a Pixie store to the specified $dsn.  This is not required for all types
of store (see L<Pixie::Store> and subclasses), but deploying to those stores
won't hurt so if you want to make your code generic then go for it.

=item $px->connect( $dsn [, @args ] )

Connect the pixie to a store specified by $dsn.  Note that you may need to
L<deploy()> the store before connecting to it.

=item $cookie = $px->insert( $object );

Stores the C<$object> and returns a $cookie which you can use to retrieve the
$object in the future.

=item $obj = $px->get( $cookie )

Get the object associated with $cookie from the pixie's store.

=item $px->delete( $obj || $cookie )

Delete an object from the pixie's store given a $cookie, or the $object
itself.

=item $px->bind_name( $name => $object )

Gives a $name to the $object you've specified, so that you can retrieve it
in the future using L<get_object_named()>.

Returns the cookie of the C<Pixie::Name> associated with the $object, though
B<this usage is deprecated and will likely be removed in the next release>.

=item $obj = $px->get_object_named( $name )

Gets the named object from the pixie's store.

=item $bool = $px->unbind_name( $name )

Stop associating $name with an object in the pixie's store.  This doesn't
delete the object itself from the store (see L<delete()> for that).

Returns true if the $name was unbound, false if not (ie: if it wasn't bound in
the first place).

=back

=head1 PLANNED API CHANGES

Some methods will be deprecated in the near future in an effort to create a
more consistent API.  Here is an overview of the planned changes:

=over 4

=item $cookie = $px->store( [ $name => ] $object )

This will replace L<insert()>, and will make naming objects easier.

=item $obj = $px->fetch( $name || $cookie )

This will replace L<get()> and L<get_object_named()>.

=item $obj->remove( $obj || $cookie || $name )

This will replace L<delete()> and L<unbind_name()>.

=back

=head1 SEE ALSO

L<Pixie::Complicity> -- Sometimes Pixie can't make an object
persistent without help from the object's class. In that case you need
to make the class 'complicit' with Pixie. You'll typically need to do
this with XS based classes that use a simple scalar as their perl
visible object representation, or with closure based classes.

L<Pixie::FinalMethods> -- There are some methods that Pixie requires
to behave in a particular way, not subject to the vagaries of
overloading. One option would be to write a bunch of private
subroutines and methods within Pixie, but very often it makes sense to
move the behaviour onto the objects being
stored. L<Pixie::FinalMethods> describes how we achieve this.

L<Pixie::Store> is the abstract interface to physical storage. If you
want to write a new backend for pixie, start here.

=head1 WITH THANKS

Jean Louis Leroy, author of Tangram, for letting us use ideas and code from
the Tangram test suite.

=head1 AUTHORS

Pixie sprang from the mind of James Duncan <james@fotango.com>. Piers
Cawley <pdcawley@bofh.org.uk> and Leon Brocard <acme@astray.org> are his
co conspiritors.

Steve Purkis <spurkis@cpan.org> is helping to maintain the module.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Fotango Ltd.

This software is released under the same license as Perl itself.

=cut
