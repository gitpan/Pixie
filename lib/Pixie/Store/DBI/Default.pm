package Pixie::Store::DBI::Default;

use strict;
use Carp;

our $VERSION = '2.02';

use DBIx::AnyDBD;
use Storable qw/nfreeze thaw/;

sub connect {
  my $class = shift;
  my($dsn, $user, $pass, $args) = @_;
  $args ||= {AutoCommit => 1, PrintError => 0, RaiseError => 1, };
  $dsn =~ s/^(dbi:)?/dbi:/;
  my $self = DBIx::AnyDBD->connect($dsn, $user, $pass, $args,
                                   'Pixie::Store::DBI');
  return unless $self;
  $self->{'reconnector'} = sub { DBI->connect($dsn, $user, $pass, $args) };
  return $self;
}


sub _init { $_[0] }

sub reconnect {
  my $self = shift;
  my $reconnector = $self->{'reconnector'}
      or croak("Can't reconnect; reconnector is missing.");

  if ($self->{'dbh'}) {
    $self->{'dbh'}->disconnect;
  }
  $self->{'dbh'} = &$reconnector()
      or croak("Can't reconnect; reconnector returned nothing");
  $self->rebless;
  $self->_init if $self->can('_init');
  return $self;
}

sub get_dbh {
  my $self = shift;

  (ref $self) or ( Carp::confess("Not a class method") );
  return $self->{'dbh'};
}


sub clear {
  my $self = shift;
  $self->prepare_execute(q{DELETE FROM object});
  return $self;
}


sub store_at {
  my $self = shift;
  my($oid, $obj) = @_;

  $self->begin_transaction;
  $self->prepare_execute(q{DELETE FROM object WHERE oid = ?},
                         $oid);
  $self->prepare_execute(q{INSERT INTO object ( oid, flat_obj )
                           VALUES ( ?, ? )},
                         $oid, nfreeze $obj);
  $self->commit;
  return($oid, $obj);
}

sub get_object_at {
  my $self = shift;
  my($oid) = @_;

  my $sth = $self->prepare_execute(q{SELECT flat_obj FROM object
                           WHERE oid = ?},
                         $oid);
  my $rows = $sth->fetchall_arrayref();
  $sth->finish;

  if (@$rows == 0) {
    return;
  }
  elsif (@$rows == 1) {
    return thaw $rows->[0][0];
  }
  else {
    croak "Too many objects matched OID: $oid";
  }
}

sub delete {
  my $self = shift;
  my($oid) = shift;

  $self->prepare_execute(q{DELETE FROM object WHERE oid = ?},
                         $oid)->rows;
}

sub prepare_execute {
  my($self, $sql, @params) = @_;

  my $sth;
  $sth = $self->prepare_cached($sql);
  for my $param_no ( 0 .. $#params ) {
    my $param_v = $params[$param_no];
    my @param_v = ( ref($param_v) eq 'ARRAY' ) ? @$param_v : $param_v;
    $sth->bind_param( $param_no+1, @param_v);
  }
  $sth->execute;
  return $sth;
}

sub begin_transaction {
  my $self = shift;
  $self->{tran_count} = 0 unless defined $self->{tran_count};
  $self->{tran_count}++;

  $self->get_dbh->{AutoCommit} = 0;
}

sub rollback_db {
  my $self = shift;

  my $dbh = $self->get_dbh;
  if (!$dbh->{AutoCommit}) {
    $dbh->rollback;
  }
  $dbh->{AutoCommit} = 1;
  $self->{tran_count} = undef;
}

sub commit {
  my $self = shift;
  my $dbh = $self->get_dbh;
  if (!$dbh->{AutoCommit}) {
    $dbh->commit;
  }
  $dbh->{AutoCommit} = 1;
  $self->{tran_count} = undef;
}

sub lock {
  my $self = shift;
  die "Something very strange is happening, you already have an active transaction"
      if $self->{locked};
  $self->{locked}++;
  $self->begin_transaction;
  return $self;
}

sub unlock {
  my $self = shift;
  $self->commit;
  $self->{locked} = 0;
  return $self;
}

sub rollback {
  my $self = shift;
  $self->rollback_db;
  $self->{locked} = 0;
  return $self;
}

1;
