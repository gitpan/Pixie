=head1 NAME

Pixie::Store::DBI::Mysql -- a MySQL Pixie store.

=head1 SYNOPSIS

  use Pixie;

  my $dsn  = 'dbi:Mysql:dbname=px_text';
  my %args = ( user => 'foo', pass => 'bar' );

  Pixie->deploy( $dsn, %args );  # only do this once

  my $px = Pixie->new->connect( $dsn );

=head1 DESCRIPTION

Implements a MySQL store for Pixie.

=cut

package Pixie::Store::DBI::Mysql;

use Carp qw( confess );
use Storable qw( nfreeze );

our $VERSION = "2.08_02";

## TODO: timeouts should really be part of a locking strategy
our $LOCK_TIMEOUT   = 60;
our $GC_LOCK_TIMOUT = 600;

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
  my $self   = shift;
  my($thing) = @_;
  $self->prepare_execute(qq{REPLACE @{[ $self->rootset_table]} (px_oid)
			    VALUES (?)},
			 $thing->PIXIE::oid);
  return $self;
}

sub begin_transaction {
  my $self = shift;

  # reconnect as needed
  #    -spurkis
  eval { $self->verify_connection };
  $self->reconnect if $@;

  my $has_lock =
    $self->selectrow_arrayref(qq{SELECT GET_LOCK('pixie', $LOCK_TIMEOUT)})
         ->[0];
  confess( "Couldn't lock pixie!" ) unless $has_lock;

  return $self;
}

sub rollback_db {
  my $self = shift;
  my $err  = $@;
  $self->do(q{SELECT RELEASE_LOCK('pixie')});
  confess "Something bad happened, and we can't roll back: $err";
}

sub commit {
  my $self = shift;
  $self->do(q{SELECT RELEASE_LOCK('pixie')});
  return $self;
}

sub lock_for_GC {
  my $self = shift;
  my $has_lock =
    $self->selectrow_arrayref(q{SELECT GET_LOCK('pixie', $GC_LOCK_TIMEOUT)})
         ->[0];
  confess( "Couldn't get GC lock" ) unless $has_lock;
  return $self;
}

sub unlock_after_GC {
  my $self = shift;
  $self->commit;
}

1;

__END__

=head1 SEE ALSO

L<Pixie>, L<Pixie::Store::DBI>, L<DBD::mysql>

=head1 AUTHORS

James Duncan <james@fotango.com>, Piers Cawley <pdcawley@bofh.org.uk>
and Leon Brocard <acme@astray.com>.

Docs by Steve Purkis <spurkis@cpan.org>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Fotango Ltd

This software is released under the same license as Perl itself.

=cut
