=head1 NAME

Pixie::Store::DBI::Pg -- a Postgresql Pixie store.

=head1 SYNOPSIS

  use Pixie;

  my $dsn  = 'dbi:Pg:dbname=px_text';
  my %args = ( user => 'foo', pass => 'bar' );

  Pixie->deploy( $dsn, %args );  # only do this once

  my $px = Pixie->new->connect( $dsn );

=head1 DESCRIPTION

Implements a Postgresql store for Pixie.

=cut

package Pixie::Store::DBI::Pg;

use strict;
use warnings;

use DBIx::AnyDBD;
use Storable qw( nfreeze );

our $VERSION = "2.08_02";

## TODO: this code shared with SQLite.pm - factor it out?
sub create_object_table {
  my $self = shift;
  $self->do(qq{CREATE TABLE @{[$self->object_table]}
	       ( px_oid VARCHAR(255) NOT NULL,
		 px_flat_obj BYTEA NOT NULL,
		 PRIMARY KEY (px_oid) ) });
  return $self;
}

## TODO: this code shared with SQLite.pm - factor it out?
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

__END__

=head1 SEE ALSO

L<Pixie>, L<Pixie::Store::DBI>, L<DBD::Pg>

=head1 AUTHORS

James Duncan <james@fotango.com>, Piers Cawley <pdcawley@bofh.org.uk>
and Leon Brocard <acme@astray.com>.

Docs by Steve Purkis <spurkis@cpan.org>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Fotango Ltd

This software is released under the same license as Perl itself.

=cut
