# (c) Sound Object Logic 2000-2001

##
## Pixie 'flat hash' tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More;

use Common;
use Springfield;

use Pixie;

my $store;
my $homer_oid;

plan tests => 14 * Common->test_stores;

for my $store_spec (Common->test_stores) {
  $store = eval { Pixie->new->connect($store_spec) };

  SKIP: {
    skip "Can't use a store_spec like: $store_spec", 14 unless $store;
    {
      my $storage = empty_store();

      my $homer = NaturalPerson->new( firstName => 'Homer',
                                      name      => 'Simpson',
                                      opinions  => { work => 'bad',
                                                     food => 'good',
                                                     beer => 'better' } );
      ok $homer_oid = $storage->insert($homer), 'insert homer';
    }

    leaktest();

    {
      my $homer = $store->get($homer_oid);
      eq_hash($homer->{opinions},
              { work => 'bad',
                food => 'good',
                beer => 'better' },
	      'homer opinions 1');
    }

    leaktest();

    {
      my $homer = $store->get($homer_oid);

      $homer->{opinions}->{'sex'} = 'good';
      $store->insert($homer);
    }

    leaktest();

    {
      my ($homer) = $store->get($homer_oid);

      is_deeply($homer->{opinions},
                { work => 'bad',
                  food => 'good',
                  beer => 'better',
                  sex  => 'good'},
		'homer opinions 2');

      delete $homer->{opinions}->{work};
      $store->insert($homer);
    }

    leaktest();

    {
      my ($homer) = $store->get($homer_oid);

      is_deeply($homer->{opinions},
                { food => 'good',
                  beer => 'better',
                  sex  => 'good' },
		'homer opinions 3');

      $homer->{opinions}->{'sex'} = 'fun';
      $store->insert($homer);
    }

    leaktest();

    {
      my ($homer) = $store->get($homer_oid);

      is_deeply($homer->{opinions},
                { food => 'good',
                  beer => 'better',
                  sex  => 'fun' },
		'homer opinions 4');

      delete $homer->{opinions};
      $store->insert($homer);
    }

    leaktest();

    {
      my ($homer) = $store->get($homer_oid);

      is_deeply($homer->{opinions}, undef, 'homer opinions 5');

      $homer->{opinions} = { work => 'bad',
                             food => 'good',
                             beer => 'better' };
      $store->insert($homer);
    }

    leaktest();

    # prefetch

    {
      my ($homer) = $store->get($homer_oid);
      {
        local ($store->{db});
        is_deeply($homer->{opinions},
                  { work => 'bad',
                    food => 'good',
                    beer => 'better' },
		  'homer opinions 6');
      }
    }

    leaktest();

    #    {
    #      my ($remote) = $store->remote('NaturalPerson');
    #      $store->prefetch($remote, 'opinions', $remote->{firstName} eq 'Homer');

    #      my ($homer) = $store->select($remote, $remote->{firstName} eq 'Homer');

    #      {
    #        local ($store->{db});
    #        is_deeply($homer->{opinions},
    #                  { work => 'bad',
    #                    food => 'good',
    #                    beer => 'better' });
    #      }
    #    }

    #    leaktest();
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

