package Pixie::Store::DBI::Pg;

use strict;
use warnings;

use DBIx::AnyDBD;

use Storable qw/nfreeze/;

sub create_object_table {
  my $self = shift;
  $self->do(qq{CREATE TABLE @{[$self->object_table]}
	       ( px_oid VARCHAR(255) NOT NULL,
		 px_flat_obj BYTEA NOT NULL,
		 PRIMARY KEY (px_oid) ) });
  return $self;
}

sub store_at {
  my $self = shift;
  my($oid, $obj, $strategy) = @_;

  my $frozen_obj = $self->escape_blob(nfreeze $obj);
  $self->begin_transaction;
  my $did_lock = $strategy->pre_store($oid, Pixie->get_the_current_pixie);
  $self->prepare_execute(qq{ DELETE FROM @{[ $self->object_table ]}
                             WHERE px_oid = ? },
                         $oid);
  $self->prepare_execute(qq{ INSERT INTO @{[ $self->object_table ]}
                             (px_oid, px_flat_obj)
                             VALUES ( ?, ? )},
                         $oid, $frozen_obj);
  $strategy->post_store($oid, Pixie->get_the_current_pixie, $did_lock);
  $self->commit;
  return($oid, $obj);
}


sub escape_blob {
  my $self = shift;
  my $blob = shift;
  use bytes;
  $blob =~ s/\\/\\\\/g;
  $blob =~ s/\'/\047/g;
  $blob =~ s/\0/\\000/g;
  return $blob;
}
1;
