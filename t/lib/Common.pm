package Common;

use strict;
use warnings;

our $BDB_AVAIL;
our $SQLITE_AVAIL;
our $TEST_DIR    = File::Spec->catdir(qw( t tmp ));
our $BDB_FILE    = File::Spec->catfile($TEST_DIR, 'bdb', 'objects.bdb' );
our $SQLITE_FILE = File::Spec->catfile($TEST_DIR, 'sqlite', 'sqlite.db' );
our $BDB_DSN     = "bdb:$BDB_FILE";
our $SQLITE_DSN  = "dbi:SQLite:dbname=$SQLITE_FILE";
our @dsn;

BEGIN {
  eval { require BerkeleyDB; };
  $BDB_AVAIL = $@ ? 0 : 1;
  eval { require DBD::SQLite; };
  $SQLITE_AVAIL = $@ ? 0 : 1;
}

sub test_stores {
  my $class = shift;
  unless (@dsn) {
    push @dsn, 'memory';
    push @dsn, $class->bdb_store if $BDB_AVAIL;
    push @dsn, $class->sqlite_store if $SQLITE_AVAIL;
    push @dsn, split / +/, $ENV{PIXIE_TEST_STORES} if
      $ENV{PIXIE_TEST_STORES};
  }
  return @dsn;
}

sub mysql_stores {
    my $class = shift;
    grep {/^dbi:mysql/i} $class->test_stores;
}

sub pg_stores {
    my $class = shift;
    grep {/^dbi:pg/i} $class->test_stores;
}

sub sqlite_stores {
    my $class = shift;
    grep {/^dbi:sqlite/i} $class->test_stores;
}

sub bdb_stores {
    my $class = shift;
    grep {/^bdb/i} $class->test_stores;
}

sub bdb_store {
    my $class = shift;
#    $class->create_test_dir; # TODO: no longer needed
    $BDB_DSN;
}

sub sqlite_store {
  my $class = shift;
  $SQLITE_DSN;
#  my $dsn   = $SQLITE_DSN;
  # TODO: no longer needed?
#  require Pixie::Store::DBI;
#  unless (-e $SQLITE_FILE) {
#      $class->create_test_dir;
#      Pixie::Store::DBI->deploy( $dsn );
#  }
#  return $dsn
}

sub create_test_dir {
  my $class = shift;

  unless (-d $TEST_DIR) {
    require File::Path;
    File::Path::mkpath( $TEST_DIR );
  }

  return $class;
}

1;
