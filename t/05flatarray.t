#!perl

use strict;
use lib 't';
use Springfield;
use Pixie;

use Test::More tests => 30;

my $store;
sub empty_store {
  $store->clear_storage;
  $store;
}
sub leaktest {
  is $SpringfieldObject::pop, 0;
  $SpringfieldObject::pop = 0;
}


for my $store_spec (qw/memory bdb:objects.bdb dbi:mysql:dbname=test/) {
  my $homer_oid;

  SKIP: {
    undef($store);
    $store = eval {Pixie->new->connect($store_spec)};
    if ($@) {
       warn $@;
       skip "Can't load $store_spec store", 10;
    }

    {
      my $storage = empty_store;
      skip "Can't use a store_spec like $store_spec", 10 unless $store;

      my $homer = NaturalPerson->new( firstName => 'Homer',
                                      name => 'Simpson',
                                      interests => [ qw( beer food ) ] );

      $homer_oid = $storage->insert($homer);
      $homer = undef;
    }
    leaktest();

    {
      my $storage = $store;
      my $homer = $storage->get($homer_oid);
      is_deeply $homer->{interests}, ['beer', 'food'];
      $homer = undef;
    }

    leaktest();

    {
      my $storage = $store;
      my $homer = $storage->get($homer_oid);
	
      push @{ $homer->{interests} }, 'sex';
      $storage->insert($homer);
      $homer = undef;
    }

    leaktest();

    {
      my $storage = $store;
      my $homer = $storage->get($homer_oid);

      is_deeply $homer->{interests}, ['beer', 'food', 'sex'];

      pop @{ $homer->{interests} };
      $storage->insert($homer);
      $homer = undef;
    }

    leaktest();

    {
      my $storage = $store;
      my $homer = $storage->get($homer_oid);

      is_deeply $homer->{interests}, ['beer', 'food'];

      unshift @{ $homer->{interests} }, 'sex';
      $storage->insert($homer);
      $homer = undef;

    }

    leaktest();

    {
      my $storage = $store;
      my $homer = $storage->get($homer_oid);

      is_deeply $homer->{interests}, ['sex', 'beer', 'food'];
	
      delete $homer->{interests};
      $storage->insert($homer);
      $homer = undef;
    }

    leaktest();
  }
}
