package Pixie::Store::BerkeleyDB;

use Storable qw/nfreeze thaw/;
use BerkeleyDB;
use File::Spec;

our $VERSION="2.06";

use base qw/Pixie::Store/;

sub new {
  my $proto = shift;
  my $self = bless { db => undef }, $proto;
  $self->init;
  return $self;
}

sub init { $_[0] }

sub connect {
  my $self = shift;
  my($vol, $dir, $file) = File::Spec->splitpath( shift );
  $dir ||= File::Spec->curdir;

  $self = $self->new unless ref $self;

  $self->db(BerkeleyDB::Hash->new
            (
             -Env =>
             BerkeleyDB::Env->new( -Home => File::Spec->catpath($vol, $dir, ''),
                                   -Flags => (DB_CREATE | DB_INIT_LOCK |
                                              DB_INIT_MPOOL |
                                              DB_INIT_TXN | DB_RECOVER), ),
             -Filename => $file,
             -Flags => DB_CREATE, ));
  return $self;
}

sub db {
  my $self = shift;

  if (@_) {
    my $db = shift;
    die "Pixie::Store::BerkeleyDB::db must be an instance of BerkeleyDB::Common"
        unless defined($db) && $db->isa('BerkeleyDB::Common');
    $self->{db} = $db;
    return $self;
  }
  else {
    return $self->{db} ||= $self->make_in_memory_db;
  }
}

sub make_in_memory_db {
  my $self = shift;
  BerkeleyDB::Hash->new( -Flags => DB_CREATE, );
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
