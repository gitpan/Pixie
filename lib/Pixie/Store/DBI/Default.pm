package Pixie::Store::DBI::Default;

use strict;
use Carp;

our $VERSION = '2.04';

use DBIx::AnyDBD;
use Storable qw/nfreeze thaw/;

sub _raw_connect {
  my $class = shift;
  my($dsn, %named_args) = @_;

  $dsn =~ s/^(dbi:)?/dbi:/;

  my $dbi_args = {AutoCommit => 1, PrintError => 0, RaiseError => 1,};

  my $self = DBIx::AnyDBD->connect($dsn, $named_args{user}, $named_args{pass},
				   $dbi_args,
                                   'Pixie::Store::DBI');
  return unless $self;
  $self->{'reconnector'} = sub { DBI->connect($dsn,  $named_args{user}, $named_args{pass},
					      $dbi_args) };
  $self->set_object_table($named_args{object_table} || 'object');
  $self->set_lock_table($named_args{lock_table} || 'lock_info');
  return $self;
}

sub connect {
  my $proto = shift;
  my $self = $proto->_raw_connect(@_);
  $self->verify_connection;
  return $self;
}

sub deploy {
  my $proto = shift;
  my $self = $proto->_raw_connect(@_);
  eval { $self->verify_connection };
  $self->_do_deployment->verify_connection;
  return $self;
}

sub _do_deployment {
  my $self = shift;
  $self->create_object_table
       ->create_lock_table
       ->create_table_index;
}

sub create_object_table {
  my $self = shift;
  $self->{dbh}->do(qq{CREATE TABLE $self->{object_table}
		        (oid varchar(255) NOT NULL,
		         flat_obj blob NOT NULL,
 		         PRIMARY KEY (oid))});
  return $self;
}

sub create_lock_table {
  my $self = shift;
  $self->{dbh}->do(qq{CREATE TABLE $self->{lock_table}
		      (oid varchar(255) NOT NULL,
		       locker varchar(255) NOT NULL,
		       PRIMARY KEY (oid))});
  return $self;
}

sub create_table_index {
  return $_[0];
}

sub set_object_table {
  my $self = shift;
  $self->{object_table} = shift;
  return $self;
}

sub object_table {
  my $self = shift;
  $self->{object_table};
}

sub set_lock_table {
  my $self = shift;
  $self->{lock_table} = shift;
  return $self;
}

sub lock_table {
  my $self = shift;
  $self->{lock_table};
}

sub verify_connection {
  my $self = shift;
  my $sth = eval { $self->prepare_execute(qq{SELECT oid, flat_obj FROM $self->{object_table} LIMIT 1}) };
  die $@ if $@;
  $sth->finish;
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
  $self->prepare_execute(q{DELETE FROM } . $self->{object_table});
  $self->prepare_execute(q{DELETE FROM } . $self->{lock_table});
  return $self;
}


sub store_at {
  my $self = shift;
  my($oid, $obj, $strategy) = @_;

  $self->begin_transaction;
  my $did_lock = $strategy->pre_store;
  $self->prepare_execute(q{DELETE FROM } . $self->{object_table} . q{ WHERE oid = ?},
                         $oid);
  $self->prepare_execute(q{INSERT INTO } . $self->{object_table} . q{ ( oid, flat_obj )
                           VALUES ( ?, ? )},
                         $oid, nfreeze $obj);
  $strategy->post_store($did_lock);
  $self->commit;
  return($oid, $obj);
}

sub get_object_at {
  my $self = shift;
  my($oid) = @_;

  my $sth = $self->prepare_execute(q{SELECT flat_obj FROM } .$self->{object_table} . q{
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

  $self->prepare_execute(q{DELETE FROM } . $self->object_table . q{ WHERE oid = ?},
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

sub lock_object_for {
  my $self = shift;
  my($oid, $pixie) = @_;
  return 0 if $self->locker_for($oid) eq $pixie->_oid;
  eval {$self->prepare_execute(q{INSERT INTO } . $self->lock_table .
			       q{ ( oid, locker )
				 VALUES ( ?, ? )},
			       $oid, $pixie->_oid)};
  die "Cannot lock $oid for $pixie: $@" if $@;
  return 1;
}

sub unlock_object_for {
  my $self = shift;
  my($oid, $pixie) = @_;
  eval { $self->prepare_execute(q{DELETE FROM } . $self->lock_table .
				q{ WHERE oid = ? AND locker = ? },
				$oid, $pixie->_oid) };
  die "Couldn't unlock $oid for $pixie: $@" if $@;
  if ( my $other_locker = $self->locker_for($oid) ) {
    die "$oid is locked by another process: $other_locker";
  }
  return 1;
}

sub locker_for {
  my $self = shift;
  my($oid) = @_;
  $oid = $oid->px_oid if ref $oid;

  my $sth = $self->prepare_execute(q{SELECT locker FROM } . $self->lock_table .
				   q{ WHERE oid = ? },
				   $oid);
  my $rows = $sth->fetchall_arrayref();
  $sth->finish;
  if ( @$rows == 0 ) {
    return '';
  }
  elsif ( @$rows == 1 ) {
    return $rows->[0][0];
  }
  else {
    croak "Too many objects matched OID: $oid";
  }
}

1;
