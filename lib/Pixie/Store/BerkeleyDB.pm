package Pixie::Store::BerkeleyDB;

use Storable qw/nfreeze thaw/;
use BerkeleyDB;
use File::Spec;

our $VERSION = '2.04';

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

sub delete {
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
1;
