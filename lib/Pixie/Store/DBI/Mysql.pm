package Pixie::Store::DBI::Mysql;

use Storable qw/nfreeze/;
use Carp;

our $VERSION='2.05';

sub store_at {
  my $self = shift;
  my($oid, $obj, $strategy) = @_;
  my $did_lock = $strategy->pre_store($oid, Pixie->get_the_current_pixie);
  $self->prepare_execute(qq{REPLACE @{[$self->object_table]} ( px_oid, px_flat_obj )
			    VALUES (?, ?)},
                         $oid, nfreeze $obj);
  $strategy->post_store($oid, Pixie->get_the_current_pixie, $did_lock);
  return($oid, $obj);
}

sub _add_to_rootset {
  my $self = shift;
  my($thing) = @_;
  $self->prepare_execute(qq{REPLACE @{[ $self->rootset_table]} (px_oid)
			    VALUES (?)},
			 $thing->PIXIE::oid);
  return $self;
}

sub begin_transaction { }

sub rollback_db {
  my $self = shift;
  $self->unlock;
  Carp::confess "Something bad happened, and we can't roll back: $@";
}
sub commit { }

1;
