package Pixie::Store::DBI::SQLite;

use strict;
use warnings;

use DBIx::AnyDBD;
use MIME::Base64;

use Storable qw/nfreeze thaw/;

sub connect {
  my $self = shift;
  $self = $self->SUPER::connect(@_);
  $self->do(' PRAGMA count_changes = ON ');
  return $self;
}

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

sub _delete {
  my $self = shift;
  my $oid  = shift;
  $self->begin_transaction;
  my $rows = $self->do(
                      qq{DELETE FROM @{[$self->object_table]}
                         WHERE px_oid = ? },
                      undef,
                      $oid
                        );
  $self->commit;
  return $rows;
}

sub get_object_at {
  my $self = shift;
  my $oid  = shift;
  $self->begin_transaction;
  my $sth = $self->prepare(qq{
                              SELECT px_flat_obj
                              FROM @{[ $self->object_table ]}
                              WHERE px_oid = ?
                              } 
                          );
  $sth->execute($oid);
  $self->commit;
  my @array = $sth->fetchrow_array;
  return undef unless $array[0];
  return thaw($self->unescape_blob( $array[0] )); 
}

sub unescape_blob {
  my $self = shift;
  my $blob = shift;
  decode_base64( $blob );
}

sub escape_blob {
  my $self = shift;
  my $blob = shift;
  encode_base64( $blob );
}
1;
