=head1 NAME

Pixie::Store::DBI::SQLite -- an SQLite Pixie store.

=head1 SYNOPSIS

  use Pixie;
  # SQLite stores don't need to be deployed
  my $px = Pixie->new->connect( 'dbi:SQLite:dbname=path/to/store.db' );

=head1 DESCRIPTION

Implements an SQLite store for Pixie.

=cut

package Pixie::Store::DBI::SQLite;

use strict;
use warnings;

use Storable qw( nfreeze thaw );
use DBIx::AnyDBD;
use MIME::Base64;

our $VERSION = '2.08_02';

sub deploy {
  my $self = shift;
  # do nothing
  return $self;
}

sub connect {
  my $self = shift;
  $self->create_dir_for_dsn( $self->{spec} );
  $self = $self->SUPER::connect(@_);
  $self->do(' PRAGMA count_changes = ON ');
  return $self;
}

## TODO: it would be nice if DBD::SQLite let us do this
sub create_dir_for_dsn {
  my $class  = shift;
  my $path  = $class->get_path_from_dsn( shift );

  require File::Basename;
  my $dir = File::Basename::dirname( $path );

  unless (-d $dir) {
    require File::Path;
    File::Path::mkpath( $dir );
  }

  return $class;
}

## TODO: it would be nice if DBD::SQLite let us do this
sub get_path_from_dsn {
  my $class  = shift;
  my $dsn    = shift;
  my ($path) = ($dsn =~ /dbname=(.+?)(?:;|\z)/i);
  return $path;
}

## TODO: this code shared with Pg.pm - factor it out?
sub create_object_table {
  my $self = shift;
  $self->do(qq{CREATE TABLE @{[$self->object_table]}
               ( px_oid VARCHAR(255) NOT NULL,
                 px_flat_obj BYTEA NOT NULL,
                 PRIMARY KEY (px_oid) ) });
  return $self;
}

## TODO: this code shared with Pg.pm - factor it out?
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
  return 0 if $rows =~ /0e0/i;
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

__END__

=head1 SEE ALSO

L<Pixie>, L<Pixie::Store::DBI>, L<DBD::SQLite>, L<DBIx::AnyDBD>

=head1 AUTHORS

James Duncan <james@fotango.com>, Piers Cawley <pdcawley@bofh.org.uk>
and Leon Brocard <acme@astray.com>.

Docs by Steve Purkis <spurkis@cpan.org>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Fotango Ltd

This software is released under the same license as Perl itself.

=cut
