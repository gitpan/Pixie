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

  $pixie->bind_name( "Some Name" => $some_object );
  my $result = $pixie->get_object_named( "Some Name" );

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

The toplevel object is a blessed array

=back

Right now, Pixie can only save blessed hashes and blessed arrays, but
it should be possible to extend it to support 'bless arbitrary
scalars'. However, during testing we found that blessed arbitrary
scalars were often used with XS classes that stored extra data where
Storable and Data::Dumper could not see it, leading to all sorts of
horrors on restoration. So we turned that feature off pending a better
approach.  Further more support for blessed regexes and blessed subroutine
references should be possible in the future with very little effort required.

Pixie can additionally be used to name objects in the store, and fetch them
later on with that name.

=cut

use strict;
use warnings::register;
use Carp;

use Data::UUID;
use Pixie::Proxy;
use Data::Dumper;
use Scalar::Util qw/ blessed reftype isweak /;
									
use Pixie::Store;
use Pixie::ObjectInfo;

use Pixie::LiveObjectManager;
use Pixie::Complicity;

use Pixie::LockStrat::Null;

our $VERSION = '2.04';
our $the_current_pixie;
our $the_current_oid;
our $the_current_lock_strategy;

use base 'Pixie::Object';


#BEGIN { $Data::Dumper::Useperl = 1 }


## CLASS METHODS
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

sub init {

  my $self = shift;

  $self->connect('memory');
  $self->{_objectmanager} = Pixie::LiveObjectManager->new->set_pixie($self);
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

sub lock_strategy_for {
  my $self = shift;
  my $obj_or_oid = shift;

  if (@_) {
    $self->{_objectmanager}->lock_strategy_for($obj_or_oid, @_);
    return $self;
  }
  else {
    return $self->{_objectmanager}->lock_strategy_for($obj_or_oid);
  }
}

sub store_individual {
  my $self = shift;
  my $real = shift;

  die "Trying to store something unstorable" if
    eval { $real->isa('Pixie::ObjectInfo') };
  my $oid = $real->PIXIE::oid;
  if (defined $oid) {
    $self->store_individual_at($real, $oid);
  }
  else {
    return $real;
  }
}


sub store_individual_at {
  my $self = shift;
  my($obj, $oid, $strategy) = @_;
  $strategy ||= $self->lock_strategy;
  if ($Pixie::Stored{$oid}) {
    return $Pixie::Stored{$oid};
  }
  else {
    return Pixie::Proxy->
      px_make_proxy($self->store->store_at($oid, $obj,$strategy));
  }
}

sub _oid {
  my $self = shift;
  $self->{_oid} ||= do {
    require Data::UUID;
    Data::UUID->new()->create_str();
  }
}

sub do_dump_and_eval {
  my $self = shift;
  my($thing, $do_lock) = @_;

  local $Data::Dumper::Deepcopy = 1;
  local $the_current_pixie = $self;

  my $data_string;
  {
    my $dump_warn;
    local $SIG{__WARN__} = sub { $dump_warn ||= join '', @_ };
    $data_string = Dumper($thing);
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

sub _insert{
  my $self = shift;
  my $this = shift;

  local %Pixie::Stored;
  local $Data::Dumper::Freezer = '_px_insertion_freeze';
  local $Data::Dumper::Toaster = '_px_insertion_thaw';

  my $proxy = $self->do_dump_and_eval($this, 1);

  return defined($proxy) ? $proxy->_oid : undef;
}

sub insert {
  my $self = shift;

  my $ret = eval { $self->_insert(@_) };
  $self->bail_out($@) if $@;
  return $ret;
}

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

sub bail_out {
  my $self = shift;
  $self->rollback_store;
  $self->unlock_store;
  die @_;
}

sub delete {
  my $self = shift;
  my $obj_or_oid  = shift;

  my $oid = ref($obj_or_oid) ? $obj_or_oid->PIXIE::oid : $obj_or_oid;
  $self->cache_delete($oid);
  $self->store->delete($oid);
}

sub forget_about {
  my $self = shift;
  return unless ref($self);
  my $obj = shift;
  $obj->PIXIE::set_info(undef);
}

sub lock_store     { $_[0]->store->lock; }
sub unlock_store   { $_[0]->store->unlock; }
sub rollback_store { $_[0]->store->rollback; }

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

sub manages_object {
  my $self = shift;
  my($obj) = @_;

  $self->_oid eq $obj->PIXIE::get_info->pixie_id;
}


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

# The naming section

sub bind_name {
  my $self = shift;
  my($name, @objects) = @_;

  require Pixie::Name;
  Pixie::Name->name_object_in($name, \@objects, $self);
}

sub unbind_name {
  my $self = shift;
  my($name) = @_;

  require Pixie::Name;
  Pixie::Name->remove_name_from($name, $self);
}

sub get_object_named {
  my $self = shift;
  my($name) = @_;
  require Pixie::Name;
  if (wantarray) {
    return (Pixie::Name->get_object_from($name, $self));
  } else {
    return Pixie::Name->get_object_from( $name, $self );
  }
}

sub ensure_storability {
  my $self = shift;
  my $obj = shift;

  $obj->px_is_storable or die "Pixie cannot store a ", ref($obj);
}

sub lock_object {
  my $self = shift;
  $self->{_objectmanager}->lock_object(@_);
}

sub unlock_object {
  my $self = shift;
  $self->{_objectmanager}->unlock_object(@_);
}

sub DESTROY {
  my $self = shift;
  delete $self->{_objectmanager};
}

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

=head1 AUTHOR

Pixie sprang from the mind of James Duncan <james@fotango.com>. Piers
Cawley <pdcawley@bofh.org.uk> and Leon Brocard <acme@astray.org> are his
co conspiritors.

=head1 COPYRIGHT

Copyright 2002 Fotango Ltd

This software is released under the same license as Perl itself.

=cut

1;
