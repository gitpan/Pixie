#!perl

##
## Pixie 'flat array' tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More;

use Common;
use Springfield;

use Pixie;

my $store;

plan tests => 15 * Common->test_stores;

for my $store_spec (Common->test_stores) {
  my $homer_oid;

  SKIP: {
    undef($store);
    $store = eval {Pixie->new->connect($store_spec)};
    if ($@) {
  #     warn $@;
       skip "Can't load $store_spec store", 15;
    }

    {
      my $storage = empty_store();
      skip "Can't use a store_spec like $store_spec", 10 unless $store;

      my $homer = NaturalPerson->new( firstName => 'Homer',
                                      name      => 'Simpson',
                                      interests => [ qw( beer food ) ] );

      $homer_oid = $storage->insert($homer);
      $homer = undef;
    }
    leaktest();

    {
      my $homer = $store->get($homer_oid);
      is $homer->PIXIE::oid, $homer_oid, 'homer oid 1';
      is_deeply $homer->{interests}, ['beer', 'food'], 'homer interests 1';
      $homer = undef;
    }

    leaktest();

    {
      my $homer = $store->get($homer_oid);
      is $homer->PIXIE::oid, $homer_oid, 'homer oid 2';

      push @{ $homer->{interests} }, 'sex';
      $store->insert($homer);
      $homer = undef;
    }

    leaktest();

    {
      my $homer = $store->get($homer_oid);
      is $homer->PIXIE::oid, $homer_oid, 'homer oid 3';

      is_deeply $homer->{interests}, ['beer', 'food', 'sex'], 'homer interests 3';

      pop @{ $homer->{interests} };
      $store->insert($homer);
      $homer = undef;
    }

    leaktest();

    {
      my $homer = $store->get($homer_oid);
      is $homer->PIXIE::oid, $homer_oid, 'homer oid 4';

      is_deeply $homer->{interests}, ['beer', 'food'], 'homer interests 4';

      unshift @{ $homer->{interests} }, 'sex';
      $store->insert($homer);
      $homer = undef;
    }

    leaktest();

    {
      my $homer = $store->get($homer_oid);
      is $homer->PIXIE::oid, $homer_oid, 'homer oid 5';

      is_deeply $homer->{interests}, ['sex', 'beer', 'food'], 'homer interests 5';

      delete $homer->{interests};
      $store->insert($homer);
      $homer = undef;
    }

    leaktest();
  }
}

sub empty_store {
  $store->clear_storage;
  $store;
}

sub leaktest {
  is $SpringfieldObject::pop, 0, 'leaktest';
  $SpringfieldObject::pop = 0;
}
