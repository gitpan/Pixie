package Common;

our $USE_BDB;
our $USE_SQLITE;
our $TEST_DIR    = File::Spec->catdir(qw( t tmp ));
our $BDB_FILE    = File::Spec->catfile($TEST_DIR, 'objects.bdb' );
our $SQLITE_FILE = File::Spec->catfile($TEST_DIR, 'sqlite.db' );
our @test_stores;

BEGIN {
  eval { require BerkeleyDB; };
  $USE_BDB = $@ ? 0 : 1;
  eval { require DBD::SQLite; };
  $USE_SQLITE = $@ ? 0 : 1;
}

sub test_stores {
  my $class = shift;
  unless (@specs) {
    push @specs, 'memory';
    push @specs, $class->bdb_store if $USE_BDB;
    push @specs, $class->sqlite_store if $USE_SQLITE;
    push @specs, split / +/, $ENV{PIXIE_TEST_STORES} if
      $ENV{PIXIE_TEST_STORES};
  }
  return @specs;
}

sub bdb_store {
  my $class = shift;
  $class->create_test_dir;
  return "bdb:$BDB_FILE";
}

sub sqlite_store {
  my $class = shift;
  my $dsn   = "dbi:SQLite:dbname=$SQLITE_FILE";
  require Pixie::Store::DBI;
  unless (-e $SQLITE_FILE) {
      $class->create_test_dir;
      Pixie::Store::DBI->deploy( $dsn );
  }
  return $dsn
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
