package Pixie::Store::DBI::Mysql;

use Storable qw/nfreeze/;

our $VERSION = '2.03';

sub store_at {
  my $self = shift;
  my($oid, $obj) = @_;
  $self->prepare_execute(q{REPLACE object ( oid, flat_obj )
                           VALUES (?, ?)},
                         $oid, nfreeze $obj);
  return($oid, $obj);
}

sub begin_transaction { }
sub rollback_db {
  Carp::confess "Something bad happened, and we can't roll back";
}
sub commit { }

1;
