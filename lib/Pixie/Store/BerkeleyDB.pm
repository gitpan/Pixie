=head1 NAME

Pixie::Store::BerkeleyDB -- a Berkeley DB Pixie store.

=head1 SYNOPSIS

  use Pixie;
  # BerkeleyDB stores don't need to be deployed
  my $px = Pixie->new->connect( 'bdb:path/to/store.bdb' );

=head1 DESCRIPTION

Implements a Berkeley DB store for Pixie.

=cut

package Pixie::Store::BerkeleyDB;

use strict;
use warnings;

use Storable qw( nfreeze thaw );
use BerkeleyDB;
use File::Spec;

use base qw( Pixie::Store );

our $VERSION = "2.08_02";

sub init {
  my $self    = shift;
  $self->{db} = undef;
  return $self;
}

## TODO: create a new object here & return it
sub deploy {
  my $class = shift;
  my $dsn   = shift;
  $dsn      =~ s/^(?:bdb:)?/bdb:/;
  $class->_create_db( $dsn );
  return $class;
}

sub connect {
  my $self = shift;
  my $dsn  = shift;
  $dsn     =~ s/^(?:bdb:)?/bdb:/;
  $self    = $self->new unless ref $self;
  $self->db( $self->_create_db( $dsn ) );
}

sub get_path_from_dsn {
    my $class  = shift;
    my $dsn    = shift;
    my ($path) = ($dsn =~ /^bdb:(.+)$/);
    $path;
}

sub _create_db {
  my $class = shift;
  my $path  = $class->get_path_from_dsn( shift );
  my $db    = $path
    ? $class->_create_db_file( $path )
    : $class->_create_db_in_memory;
  croak( "error connecting to BerkeleyDB at [$path]: $BerkeleyDB::Error" )
    unless $db;
  return $db;
}

sub _create_db_file {
    my $class = shift;
    my $path  = shift;

    my($vol, $dir, $file) = File::Spec->splitpath( $path );
    $dir ||= File::Spec->curdir;

    unless (-d $dir) {
	require File::Path;
	File::Path::mkpath( $dir );
    }

    BerkeleyDB::Hash->new
      (
       -Filename => $file,
       -Flags    => DB_CREATE,
       -Env => BerkeleyDB::Env->new(
				    -Home => File::Spec->catpath($vol, $dir, ''),
				    -Flags => ( DB_CREATE | DB_INIT_LOCK |
						DB_INIT_MPOOL |
						DB_INIT_TXN | DB_RECOVER ),
				   ),
      );
}

sub _create_db_in_memory {
  my $class = shift;
  BerkeleyDB::Hash->new( -Flags => DB_CREATE, );
}

sub db {
  my $self = shift;
  if (@_) {
    my $db = shift;
    croak( "db must be a BerkeleyDB::Common" )
      unless UNIVERSAL::isa( $db, 'BerkeleyDB::Common' );
    $self->{db} = $db;
    return $self;
  }
  else {
    return $self->{db} ||= $self->_create_db_in_memory;
  }
}

sub store_at {
  my $self = shift;
  my($oid, $obj) = @_;

  $self->db->db_put($oid, nfreeze($obj));
  return ($oid, $obj);
}

sub get_object_at {
  my $self = shift;
  my($oid) = @_;
  my($val);

  $self->db->db_get($oid,$val);

  return thaw $val;
}

sub _delete {
  my $self = shift;
  my($oid) = @_;
  my $val;
  my $db = $self->db;
  my $ret = $db->db_get($oid, $val) == 0;
  $db->db_del($oid);
  return $ret;
}

sub clear {
  my $self = shift;
  $self->lock;
  my $cursor = $self->db->db_cursor;
  my($k,$v) = ('','');
  while ($cursor->c_get($k,$v, DB_NEXT) != DB_NOTFOUND) {
    $cursor->c_del
  }
  $cursor->c_close;
  $self->unlock;
}

sub lock { $_[0] }
sub unlock { $_[0] }
sub rollback { $_[0] }

sub rootset {
  my $self = shift;
  my @set = $self->_rootset_hash->keys;
  return @set;
}

sub _rootset_hash {
  my $self = shift;
  my $set = shift;
  unless ($set = $self->get_object_at('<NAME:PIXIE::rootset>')) {
    $set = Pixie::BDB::Rootset->new;
  }
  return $set;
}

sub db_keys {
  my $self = shift;
  my @keys;
  my $cursor = $self->db->db_cursor;
  my($k,$v) = ('','');
  push @keys, $k while $cursor->c_get($k,$v, DB_NEXT) == 0;
  return @keys;
}

sub working_set_for {
  my $self = shift;
  my $pixie = shift;
  my %set = map { $_ => undef } grep !/^<NAME:PIXIE::/, $self->db_keys;
  delete $set{$self->object_graph_for($pixie)->PIXIE::oid};
  wantarray ? keys %set : [keys %set];
}

sub _add_to_rootset {
  my $self = shift;
  my $oid = shift->PIXIE::oid;
  my $set = $self->_rootset_hash;
  $set->{$oid} = 1;
  $self->store_at('<NAME:PIXIE::rootset>' => $set);
  return $self;
}

sub remove_from_rootset {
  my $self = shift;
  my $oid = shift;
  my $set = $self->_rootset_hash;
  delete $set->{$oid};
  $self->store_at('<NAME:PIXIE::rootset>' => $set);
  return $self;
}


package Pixie::BDB::Rootset;

sub new { bless {}, $_[0] }
sub keys { keys %{$_[0]} }

1;

__END__

=head1 SEE ALSO

L<Pixie>, L<Pixie::Store::DBI>, L<BerkeleyDB>

=head1 AUTHORS

James Duncan <james@fotango.com>, Piers Cawley <pdcawley@bofh.org.uk>
and Leon Brocard <acme@astray.com>.

Docs by Steve Purkis <spurkis@cpan.org>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Fotango Ltd

This software is released under the same license as Perl itself.

=cut
