##
# NAME
#   Pixie::LiveObjectManager - manages in-memory cache of objects
#
# SYNOPSIS
#   use Pixie::LiveObjectManager;
#
#   my $obj_manager = Pixie::LiveObjectManager->new->set_pixie( $pixie );
#   my $obj = Foo->new;
#
#   # insert weak copy of $obj into the cache:
#   my ($oid) = $obj_manager->cache_insert( $obj );
#   my $obj2  = $obj_manager->cache_get( $oid );
#   print $obj_manager->cache_size;
#   ... for $obj_manager->cache_keys;
#   $obj_manager->cache_delete( $oid );
#
#   # still dunno about this one:
#   $obj_manager->bind_object_to_oid( $obj_holder => $oid );
#
# $obj_manager->lock_strategy_for
# $obj_manager->lock_object / $obj_manager->unlock_object
#
##

package Pixie::LiveObjectManager;

use strict;

use Carp qw( confess );
use Scalar::Util qw( blessed weaken isweak );
use Pixie::Object;
use Pixie::ObjectInfo;
use Pixie::FinalMethods;

use base qw( Pixie::Object );

our $VERSION = "2.08_02";

sub init {
  my $self = shift;
  $self->{_live_cache} = {};
  return $self;
}

#-----------------------------------------------------------------------------
# Cache methods
#-----------------------------------------------------------------------------

sub cache_insert {
  my $self = shift;
  my $obj  = shift;

  confess( "can't insert a Pixie::ObjectInfo into the cache!" )
    if $obj->isa('Pixie::ObjectInfo');

  my $info = $obj->PIXIE::get_info;
  my $oid  = $info->_oid;

  no warnings 'uninitialized';
  if ( length($oid) && ! defined($self->{_live_cache}{$oid}) ) {
    weaken( $self->{_live_cache}{$oid} = $info );
    # $info->set_lock_strategy(Pixie->get_the_current_lock_strategy);
  }

  return $oid => $obj;
}

sub cache_get {
  my $self = shift;
  my($oid) = @_;

  defined $oid or return;
  if ( defined $self->{_live_cache}{$oid} ) {
    return  $self->{_live_cache}{$oid}->the_object;
  }
  else {
    return;
  }
}

sub cache_delete {
  my $self = shift;
  my($oid) = @_;
  $oid = $self->get_oid_for($oid) if blessed( $oid );
  delete $self->{_live_cache}{$oid};
}

sub cache_size {
  my $self = shift;
  scalar keys %{$self->{_live_cache}};
}

sub cache_keys {
    my $self = shift;
    keys %{$self->{_live_cache}};
}

#-----------------------------------------------------------------------------
# Live Object Management
#-----------------------------------------------------------------------------

## TODO: use an accessor for pixie
sub set_pixie {
  my $self       = shift;
  $self->{pixie} = shift;
  weaken $self->{pixie};
  return $self;
}

sub bind_object_to_oid {
  my $self       = shift;
  my($obj, $oid) = @_;
  my $info       = $self->get_info_for_oid($oid) || $obj->PIXIE::get_info;

  # TODO: what happens if $obj != $info->the_object ?
  $info->set_the_object($obj) unless defined($info->the_object);
  $info->set__oid($oid);
  $info->set_pixie($self->{pixie});
  $info->set_lock_strategy( Pixie->get_the_current_lock_strategy ||
			    $self->{pixie}->lock_strategy );
  $obj->PIXIE::set_info($info);
}

sub lock_object {
  my $self = shift;
  my($obj) = @_;

  $self->assert_ownership_of($obj);
  $self->{pixie}->store->lock_object_for(scalar($self->get_oid_for($obj)),
					 $self->{pixie});
}

sub unlock_object {
  my $self = shift;
  my($obj) = @_;

  $self->assert_ownership_of($obj);
  $self->{pixie}->store->unlock_object_for(scalar($self->get_oid_for($obj)),
					   $self->{pixie});
}

sub assert_ownership_of {
  my $self = shift;
  my($obj) = @_;
  confess( "The object is not managed by this pixie!" ) unless
    $self->{pixie}->manages_object($obj);
}

sub lock_strategy_for {
  my $self = shift;
  my $oid  = shift;
  my $info = $self->get_info_for($oid);

  # TODO: eek! this a bad place to act as an accessor...
  #       maybe set_lock_strategy_for(), or just let caller do it?
  if (@_) {
    $info->set_lock_strategy(@_);
  }

  $info->lock_strategy;
}

sub get_info_for {
  my $self  = shift;
  my $thing = shift;
  return blessed($thing)
    ? $thing->PIXIE::get_info
    : $self->get_info_for_oid( $thing );
}

sub get_info_for_oid {
  my $self = shift;
  my $oid  = shift;
  $self->{_live_cache}{$oid};
}

sub get_oid_for {
  my $self = shift;
  my $obj  = shift;

  return unless defined( $obj ) && blessed $obj;
  confess( "Can't get oid for a Pixie::ObjectInfo!" )
    if eval { $obj->isa('Pixie::ObjectInfo') };

  $obj->PIXIE::oid
}

sub DESTROY {
  my $self = shift;
  local $@; # protect $@
  foreach my $obj (grep defined,
		   map $_->the_object,
		   grep defined,
		   values %{ $self->{_live_cache} })
  {
    eval { $self->unlock_object( $obj ) };
    $obj->PIXIE::set_info( undef );
  }
}

1;
