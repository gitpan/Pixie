#!perl -w


package TestDBI;

use base 'Test::Class';
use Test::More;
use Test::Exception;

use Pixie::Store::DBI;

use strict;

sub new {
  my $proto = shift;
  my $self = $proto->SUPER::new();
  my $spec = shift;

  $self->{spec} = $spec;
  return $self;
}

sub test_default : Test {
  my $self = shift;
  ok(Pixie::Store::DBI->connect($self->{spec}));
}

sub test_with_tablename : Test {
  my $self = shift;
  ok my $p = Pixie::Store::DBI->connect($self->{spec}, object_table => 'px_object');
}

sub test_with_bad_tablename : Test {
  my $self = shift;
  dies_ok {Pixie::Store::DBI->connect($self->{spec}, object_table => 'nonexistent')}
}

sub test_deployment : Test(3) {
  my $self = shift;
  $self->test_with_bad_tablename or die "Nonexistent table already exists!";
  lives_ok {
    Pixie::Store::DBI->deploy($self->{spec},
			      object_table => 'nonexistent',
			      lock_table => 'nonexistent2',
			      rootset_table => 'nonexistent3',)}
    "Deployment";
  my $store;
  lives_ok {
    $store = Pixie::Store::DBI->connect($self->{spec},
					object_table => 'nonexistent',
					lock_table => 'nonexistent2',
				        rootset_table => 'nonexistent3',) }
    "Connection";
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent})};
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent2})};
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent3})};
}


package main;

my @specs;
push @specs, grep /^dbi:/, split / +/, $ENV{PIXIE_TEST_STORES} if $ENV{PIXIE_TEST_STORES};

unless (@specs) {
  Test::More::plan skip_all => "No DBI stores";
  exit;
}

my @testers;

foreach my $store (@specs) {
  eval {
    my $tester = TestDBI->new($store);
    push @testers, $tester if $tester;
  }
}

Test::Class->runtests(@testers);
