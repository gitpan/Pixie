#!perl -w


package TestDBI;

use base 'Test::Class';
use Test::More;
use Test::Exception;

use strict;

eval "use DBI; use DBD::mysql";

if ($@) {
  plan skip_all => "DBI won't load";
  exit;
}

eval { use Pixie::Store::DBI; my $c = Pixie::Store::DBI->connect('dbi:mysql:dbname=test') };

if ($@) {
  plan skip_all => "Can't connect to test database: $@";
}

sub test_default : Test {
  ok(Pixie::Store::DBI->connect('dbi:mysql:dbname=test'));
}

sub test_with_tablename : Test {
  ok my $p = Pixie::Store::DBI->connect('dbi:mysql:dbname=test', object_table => 'object');
}

sub test_with_bad_tablename : Test {
  dies_ok {Pixie::Store::DBI->connect('dbi:mysql:dbname=test', object_table => 'nonexistent')}
}

sub test_deployment : Test(3) {
  my $self = shift;
  $self->test_with_bad_tablename or die "Nonexistent table already exists!";
  lives_ok {
    Pixie::Store::DBI->deploy('dbi:mysql:dbname=test',
			      object_table => 'nonexistent',
			      lock_table => 'nonexistent2')}
    "Deployment";
  my $store;
  lives_ok {
    $store = Pixie::Store::DBI->connect('dbi:mysql:dbname=test',
					object_table => 'nonexistent',
					lock_table => 'nonexistent2') }
    "Connection";
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent})};
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent2})};
}


package main;

Test::Class->runtests('TestDBI');
