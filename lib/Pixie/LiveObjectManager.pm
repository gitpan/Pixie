package Pixie::LiveObjectManager;

use strict;

use Pixie::Object;
use Pixie::FinalMethods;
use base 'Pixie::Object';

use Pixie::ObjectInfo;
use Carp;

our $VERSION='2.05';

use Scalar::Util qw/blessed weaken isweak/;

sub init {
  my $self = shift;
  $self->{_live_cache} = {};
  return $self;
}

sub cache_insert {
  my $self = shift;
  my $obj = shift;

  die if $obj->isa('Pixie::ObjectInfo');
  my $info = $obj->PIXIE::get_info;
  my $oid = $info->_oid;
  no warnings 'uninitialized';
  if ( length($oid) && ! defined($self->{_live_cache}{$oid}) ) {
    weaken($self->{_live_cache}{$oid} = $info);
    $info->set_the_container($self->{_live_cache});
    $info->set_lock_strategy(Pixie->get_the_current_lock_strategy);
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
  $oid = $self->get_oid_for($oid) if ref($oid);
  delete $self->{_live_cache}{$oid};
}

sub cache_size {
  my $self = shift;
  scalar keys %{$self->{_live_cache}};
}

sub get_info_for {
  my $self = shift;
  my $thing = shift;
  return ref($thing) ? $thing->PIXIE::get_info
                     : $self->get_info_for_oid($thing);
}

sub get_info_for_oid {
  my $self = shift;
  my $oid = shift;
  $self->{_live_cache}{$oid};
}

sub set_pixie {
  my $self = shift;
  my $pixie = shift;
  $self->{pixie} = $pixie;
  weaken $self->{pixie};
  return $self;
}

sub bind_object_to_oid {
  my $self = shift;
  my($obj, $oid) = @_;
  my $info =  $self->get_info_for_oid($oid)
    || $obj->PIXIE::get_info;

  $info->set_the_object($obj) unless defined($info->the_object);
  $info->set__oid($oid);
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
  die "The object is not managed by this pixie" unless 
    $self->{pixie}->manages_object($obj);
}

sub lock_strategy_for {
  my $self = shift;
  my $oid = shift;

  my $info = $self->get_info_for($oid);
  $info->lock_strategy;
}

sub get_oid_for {
  my $self = shift;
  my $obj = shift;

  return unless defined($obj) && blessed $obj;
  Carp::confess "You should't call this on a Pixie::ObjectInfo" if 
    eval { $obj->isa('Pixie::ObjectInfo') };
  $obj->PIXIE::oid
}

sub DESTROY {
  my $self = shift;
  local $@; # protect $@
  for (grep defined,
       map $_->the_object,
       grep defined,
       values %{$self->{_live_cache}})
  {
    eval {$self->unlock_object($_)};
    $_->PIXIE::set_info();
  }
}

1;
