#  package Pixie::Store::DBI::Mysql;

#  use Storable qw/nfreeze/;
#  use Carp;

#  our $VERSION="2.06";

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

sub begin_transaction {
  my $self = shift;
  my $has_lock =
    $self->selectrow_arrayref(q{SELECT GET_LOCK('pixie', 60)})
      ->[0];
  die "Couldn't lock pixie!" unless $has_lock;
  return $self;
}

sub rollback_db {
  my $self = shift;
  my $err = $@;
  $self->do(q{SELECT RELEASE_LOCK('pixie')});
  Carp::confess "Something bad happened, and we can't roll back: $err";
}

sub commit {
  my $self = shift;
  $self->do(q{SELECT RELEASE_LOCK('pixie')});
  return $self;
}

sub lock_for_GC {
  my $self = shift;
  my $has_lock =
    $self->selectrow_arrayref(q{SELECT GET_LOCK('pixie', 600)})
      ->[0];
  die "Couldn't get GC lock" unless $has_lock;
  return $self;
}

sub unlock_after_GC {
  my $self = shift;
  $self->commit;
}
1;
