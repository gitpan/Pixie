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

use Data::UUID;
use Pixie::Hook;
use Pixie::Proxy;
use Data::Dumper;
use Scalar::Util qw/ blessed weaken reftype isweak /;
									
use Pixie::Store;
use Pixie::ObjectInfo;

use Pixie::OidManager;
use Pixie::ShadowManager;

our $VERSION = '2.02';
our $the_current_pixie;
our $the_current_oid;

use base 'Pixie::Object';

sub init {
  my $self = shift;

  $self->hook( Pixie::Hook->new() );
  $self->connect('memory');
  $self->{cache} = {};
  $self->{_oidmanager} = Pixie::OidManager->new->set_pixie($self);
  $self->{_shadow_class_manager} = Pixie::ShadowManager->new->set_pixie($self);
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

  die "Trying to store something unstorable" if
    eval { $real->isa('Pixie::ObjectInfo') };
  my $oid = $self->oid( $real );
  if (defined $oid) {
    $self->store_individual_at($real, $oid);
  }
  else {
    return $real;
  }
}


sub store_individual_at {
  my $self = shift;
  my($obj, $oid) = @_;
  if ($Pixie::Stored{$oid}) {
    return $Pixie::Stored{$oid};
  }
  else {
    return $self->make_proxy($self->store->store_at($oid => $obj));
  }
}

sub make_proxy {
  my $self = shift;

  Pixie::Proxy->make_proxy(@_);
}

sub oid {
  my $self = shift;
  my $oid = $self->{_oidmanager}->get_oid_for(@_);
  return wantarray ? ($oid, 0) : $oid;
}

sub insert {
  my $self = shift;
  my $this = shift;

  local %Pixie::Stored;
  $self->oid($this);

  local $Data::Dumper::Freezer = 'px_insertion_freeze';
  local $Data::Dumper::Toaster = 'px_insertion_thaw';
  local $Data::Dumper::Deepcopy = 1;

  no warnings qw/redefine/;
  local *UNIVERSAL::px_insertion_freeze = eval {
    my $pixie = $self;
    sub {
      my $self = shift;
      my($oid) = $pixie->cache_insert($self);
      bless { oid => $oid,
	      class => $self->real_class,
	      content => $self->px_as_rawstruct }, 'Pixie::ObjHolder';
    }
  };

  local *Pixie::ObjHolder::px_insertion_thaw = eval {
    my $pixie = $self;
    sub {
      my $obj_holder = shift;
      my $class = $obj_holder->{class};
      my $self = bless $obj_holder->{content}, $class;

      $pixie->{_oidmanager}->bind_object_to_oid($self, $obj_holder->{oid});

      unless ($pixie->can_store($self, $class)) {
	warnings::warn("Don't know how to insert a $class");
	return undef;
      }
      my $retval = $pixie->store_individual_at( $self, $obj_holder->{oid});
#      $self = $pixie->rebless_into_shadow_class($self);
#      $self->_PIXIE_dont_do_real_DEST(1);
      bless $self, 'Class::Whitehole';
      $pixie->{_oidmanager}->forget_object($self);
      return $retval;
    }
  };

  $self->lock_store;

  my $data_string = Dumper($this);
  my $VAR1;

  my $proxy = eval $data_string;
  $self->weaken_cache;
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
  my $res;
  {
    local $Pixie::Proxy::NOCACHEFLUSH = 1;
    $self->lock_store;
    $res = eval { $self->_get(@_) };
    $self->unlock_store;
    die $@ if $@;
  }
  $self->weaken_cache;
  $self->cleanup_cache;
  return $res;
}

sub delete {
  my $self = shift;
  my $obj_or_oid  = shift;

  my $oid = ref($obj_or_oid) ? $self->oid($obj_or_oid) : $obj_or_oid;
  $self->cache_delete($oid);
  $self->store->delete($oid);
}

sub forget_about {
  my $self = shift;
  return unless ref($self);
  my $obj = shift;
  $self->{_oidmanager}->forget_object($obj);
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

  local $Data::Dumper::Freezer = 'px_extraction_freeze';
  local $Data::Dumper::Toaster = 'px_extraction_thaw';
  local $Data::Dumper::Deepcopy = 1;
  local $the_current_pixie = $self;
  local $the_current_oid = $oid;

  my $rawstruct = $self->store->get_object_at( $oid );
  return unless defined($rawstruct);

  my $data_string = Dumper($rawstruct);
  my $VAR1;
  eval $data_string;
  die $@ if $@;
  $rawstruct = $self->rebless_into_shadow_class($rawstruct);
  $rawstruct->_PIXIE_dont_do_real_DEST(1);
  return $VAR1;
}

sub UNIVERSAL::px_extraction_freeze {
  shift;
}

sub UNIVERSAL::px_extraction_thaw {
  my $self  = shift;
  my $class = ref($self);
  my $pixie = $the_current_pixie;
  my $oid   = $the_current_oid;

  $self = $pixie->rebless_into_shadow_class($self);
  $self->_PIXIE_dont_do_real_DEST(1);

  my $real_obj = $pixie->make_new_object($self, $class);
  $pixie->{_oidmanager}->bind_object_to_oid($real_obj => $oid);
  $pixie->oid($real_obj) eq $oid or die "Bad OID stuff";
  $pixie->cache_insert($real_obj);
  return $real_obj;
}


sub make_new_object {
  my $self = shift;
  my($struct, $class) = @_;

  my $real = eval { $class->new };
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
  require Carp;
  return $obj if $obj->isa('Pixie::ObjectInfo');
  $obj = $self->rebless_into_shadow_class($obj);
  my $oid = $self->oid($obj);
  no warnings 'uninitialized';
  if (length($oid) && ! defined($self->{cache}{$oid}) ) {
    $self->{cache}{$oid} = $obj;
#    weaken $self->{cache}{$oid};
  }
  return $oid, $obj;
}

sub weaken_cache {
  my $self = shift;
  no warnings 'uninitialized';
  my $cache = $self->{cache};
  for my $key (keys %$cache) {
    (isweak($$cache{$key}) || weaken($$cache{$key}));
  }
  return $self;
}


sub cleanup_cache {
  my $self = shift;
  for (keys %{$self->cache}) {
    delete $self->cache->{$_} unless defined $self->cache->{$_};
  }
}

sub cache_size {
  my $self = shift;
  return scalar keys %{$self->cache};
}

sub rebless_into_shadow_class {
  my $self = shift;
  $self->{_shadow_class_manager}->rebless(shift);
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

sub UNIVERSAL::px_is_not_proxiable {

}

sub UNIVERSAL::px_as_rawstruct {
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
