package Pixie::Store::DBI::Default;

use strict;
use Carp;

our $VERSION="2.06";

use DBIx::AnyDBD;
use Storable qw/nfreeze thaw/;

use base 'Pixie::Store';

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
  $self->set_object_table($named_args{object_table}   || 'px_object');
  $self->set_lock_table($named_args{lock_table}       || 'px_lock_info');
  $self->set_rootset_table($named_args{rootset_table} || 'px_rootset');
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
       ->create_table_index
       ->create_rootset_table
}

sub create_object_table {
  my $self = shift;
  $self->{dbh}->do(qq{CREATE TABLE $self->{object_table}
                        (px_oid varchar(255) NOT NULL,
                         px_flat_obj blob NOT NULL,
                         PRIMARY KEY (px_oid))});
  return $self;
}

sub create_lock_table {
  my $self = shift;
  $self->{dbh}->do(qq{CREATE TABLE $self->{lock_table}
                      (px_oid varchar(255) NOT NULL,
                       px_locker varchar(255) NOT NULL,
                       PRIMARY KEY (px_oid))});
  return $self;
}

sub create_rootset_table {
  my $self = shift;
  $self->{dbh}->do(qq{CREATE TABLE $self->{rootset_table}
                      (px_oid varchar(255) NOT NULL,
                       PRIMARY KEY (px_oid))});
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

sub set_rootset_table {
  my $self = shift;
  $self->{rootset_table} = shift;
  return $self;
}

sub rootset_table {
  my $self = shift;
  $self->{rootset_table};
}

sub verify_connection {
  my $self = shift;
  my $sth = $self->prepare_execute(qq{SELECT px_oid, px_flat_obj
				      FROM $self->{object_table} LIMIT 1});
  $sth->finish if $sth;
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
  $self->prepare_execute(qq{DELETE FROM $_}) for map $self->$_(),
    qw/object_table lock_table rootset_table/;
  return $self;
}


sub store_at {
  my $self = shift;
  my($oid, $obj, $strategy) = @_;

  $self->begin_transaction;
  my $did_lock = $strategy->pre_store($oid, Pixie->get_the_current_pixie);
  $self->prepare_execute(qq{ DELETE FROM @{[ $self->object_table ]}
                             WHERE px_oid = ? },
                         $oid);
  $self->prepare_execute(qq{ INSERT INTO @{[ $self->object_table ]}
                             (px_oid, px_flat_obj)
                             VALUES ( ?, ? )},
                         $oid, nfreeze $obj);
  $strategy->post_store($did_lock, Pixie->get_the_current_pixie);
  $self->commit;
  return($oid, $obj);
}

sub get_object_at {
  my $self = shift;
  my($oid) = @_;

  my $sth = $self->prepare_execute(q{SELECT px_flat_obj FROM } .$self->{object_table} . q{ WHERE px_oid = ? },
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

sub _delete {
  my $self = shift;
  my($oid) = shift;

  $self->prepare_execute(q{DELETE FROM } .
                         $self->object_table .
                         q{ WHERE px_oid = ?}, $oid)->rows;
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
  eval { $sth->execute };
  Carp::confess $@ if $@;
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
  $self->begin_transaction;
  return $self;
}

sub unlock {
  my $self = shift;
  $self->commit;
  return $self;
}

sub rollback {
  my $self = shift;
  $self->rollback_db;
  return $self;
}

sub remove_from_rootset {
  my $self = shift;
  my($oid) = @_;

  $self->prepare_execute(qq{DELETE FROM @{[ $self->rootset_table ]}
                            WHERE px_oid = ?},
                         $oid);
  return $self;
}

sub _add_to_rootset {
  my $self = shift;
  my($thing) = @_;
  $self->begin_transaction;
  $self->prepare_execute(qq{DELETE FROM @{[ $self->rootset_table ]}
                            WHERE px_oid = ?},
                         $thing->PIXIE::oid);
  $self->prepare_execute(qq{INSERT INTO @{[ $self->rootset_table ]} (px_oid)
                            VALUES ( ? )},
                         $thing->PIXIE::oid);
  $self->commit;
  return $self;
}


sub rootset {
  my $self = shift;
  my $rows = $self->selectall_arrayref(qq{SELECT px_oid FROM @{[$self->rootset_table]}
					  WHERE px_oid NOT LIKE '<NAME:PIXIE::\%'}) ;
  my @ary = map $_->[0], @$rows;
  return wantarray ? @ary : \@ary;
}

sub working_set_for {
  my $self = shift;
  my $p = shift;
  my $rows = $self->selectall_arrayref(
    qq{SELECT px_oid FROM @{[$self->object_table]}
       WHERE px_oid NOT LIKE '<NAME:PIXIE::\%' AND
       NOT(px_oid = '@{[$self->object_graph_for($p)->PIXIE::oid]}')});

  my @ary = map $_->[0], @$rows;
  return wantarray ? @ary : \@ary;
}

sub lock_object_for {
  my $self = shift;
  my($oid, $pixie, $timeout) = @_;
  $timeout = 30 unless defined $timeout;
  my $lock_holder = $self->locker_for($oid);
  return 0 if $lock_holder eq $pixie->_oid;
  my $keep_trying = 1;
  local $SIG{ALRM} = sub { $keep_trying = 0 };
  alarm $timeout;
  while ($keep_trying) {
    eval {$self->prepare_execute(q{INSERT INTO } . $self->lock_table .
				 q{ ( px_oid, px_locker )
				    VALUES ( ?, ? )},
				 $oid, $pixie->_oid)};
    last unless $keep_trying && $@;
    select undef, undef, undef, rand(2 * 1000);
  }
  alarm 0;
  $lock_holder = $self->locker_for($oid);
  unless ($lock_holder eq $pixie->_oid) {
    die "Cannot lock $oid for $pixie. Lock is held by ", $lock_holder;
  }
  $self->SUPER::lock_object_for($oid, $pixie);
  return 1;
}

sub unlock_object_for {
  my $self = shift;
  my($oid, $pixie) = @_;
  my $pixie_oid = ref($pixie) ? $pixie->_oid : $pixie;
  eval { $self->prepare_execute(q{DELETE FROM } . $self->lock_table .
                                q{ WHERE px_oid = ? AND px_locker = ? },
                                $oid, $pixie_oid) };
  die "Couldn't unlock $oid for $pixie_oid: $@" if $@;
  if ( my $other_locker = $self->locker_for($oid) ) {
    die "$oid is locked by another process: $other_locker";
  }
  $self->SUPER::unlock_object_for($oid, $pixie);
  return 1;
}

sub locker_for {
  my $self = shift;
  my($oid) = @_;
  $oid = $oid->px_oid if ref $oid;

  my $sth = $self->prepare_execute(q{SELECT px_locker FROM } . $self->lock_table .
                                   q{ WHERE px_oid = ? },
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

sub release_all_locks {
    my $self = shift;
    # Ensure a connection
    $self->{dbh} = &{$self->{reconnector}}
        unless $self->{dbh};
    $self->SUPER::release_all_locks;
}

sub DESTROY {
    my $self = shift;
    $self->release_all_locks;
    $self->SUPER::DESTROY;
}
1;
