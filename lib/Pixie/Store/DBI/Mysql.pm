package Pixie::Store::DBI::Mysql;

use Storable qw/nfreeze/;
use Carp;

our $VERSION = '2.04';

sub store_at {
  my $self = shift;
  my($oid, $obj, $strategy) = @_;
  my $did_lock = $strategy->pre_store($oid, Pixie->get_the_current_pixie);
  $self->prepare_execute(q{REPLACE object ( oid, flat_obj )
                           VALUES (?, ?)},
                         $oid, nfreeze $obj);
  $strategy->post_store($oid, Pixie->get_the_current_pixie, $did_lock);
  return($oid, $obj);
}

sub begin_transaction { }
sub rollback_db {
  my $self = shift;
  $self->unlock;
  Carp::confess "Something bad happened, and we can't roll back: $@";
}
sub commit { }

1;
