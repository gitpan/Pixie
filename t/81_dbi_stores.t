#!perl -w

BEGIN { warn "\n\nWARNING: $0 is REDUNDANT -- covered by tests 55-60\n\n\n"; }


##
## Pixie DBI Store tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More;
use Test::Class;

use Common;

my @dsns = grep /^dbi:/, Common->test_stores;
plan skip_all => "No DBI stores" unless (@dsns);

my @testers = grep defined, map TestDBI->new($_), @dsns;
Test::Class->runtests(@testers);


package TestDBI;

use strict;

use Test::More;
use Test::Exception;

use Pixie::Store::DBI;

use base 'Test::Class';

sub new {
  my $proto = shift;
  my $self  = $proto->SUPER::new();
  my $dsn   = shift;

  $self->{dsn} = $dsn;
  return $self;
}

sub test_default : Test {
  my $self = shift;
  ok(Pixie::Store::DBI->connect($self->{dsn}));
}

sub test_with_tablename : Test {
  my $self = shift;
  ok my $p = Pixie::Store::DBI->connect($self->{dsn}, object_table => 'px_object');
}

sub test_with_bad_tablename : Test {
  my $self = shift;
  dies_ok {Pixie::Store::DBI->connect($self->{dsn}, object_table => 'nonexistent')}
}

sub test_deployment : Test(3) {
  my $self = shift;
  $self->test_with_bad_tablename or die "Nonexistent table already exists!";
  lives_ok {
    Pixie::Store::DBI->deploy($self->{dsn},
			      object_table => 'nonexistent',
			      lock_table => 'nonexistent2',
			      rootset_table => 'nonexistent3',)}
    "Deployment";
  my $store;
  lives_ok {
    $store = Pixie::Store::DBI->connect($self->{dsn},
					object_table => 'nonexistent',
					lock_table => 'nonexistent2',
				        rootset_table => 'nonexistent3',) }
    "Connection";
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent})}  || warn $@;
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent2})} || warn $@;
  eval {$store->{dbh}->do(q{DROP TABLE nonexistent3})} || warn $@;
}

