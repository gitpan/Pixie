# (c) Sound Object Logic 2000-2001

use strict;
use lib 't';
use blib;
use Springfield;

use Pixie;

use Test::More;

my $store;

sub empty_store {
  $store->clear_storage;
  $store;
}
sub leaktest {
  is $SpringfieldObject::pop, 0;
  $SpringfieldObject::pop = 0;
}

my $homer_oid;

my @specs = qw/memory bdb:objects.bdb/;
push @specs, split / +/, $ENV{PIXIE_TEST_STORES} if $ENV{PIXIE_TEST_STORES};

plan tests => 14 * @specs;


for my $store_spec (@specs) {
  $store = eval { Pixie->new->connect($store_spec) };

  SKIP: {
    skip "Can't use a store_spec like: $store_spec", 14 unless $store;
    {
      my $storage = empty_store;

      my $homer = NaturalPerson->new( firstName => 'Homer',
                                      name => 'Simpson',
                                      opinions => { work => 'bad',
                                                    food => 'good',
                                                    beer => 'better' } );
      ok $homer_oid = $storage->insert($homer);
    }

    leaktest();

    {
      my $storage = $store;
      my $homer = $storage->get($homer_oid);
      eq_hash($homer->{opinions},
              { work => 'bad',
                food => 'good',
                beer => 'better' });

    }

    leaktest();

    {
      my $storage = $store;
      my $homer = $storage->get($homer_oid);

      $homer->{opinions}->{'sex'} = 'good';
      $storage->insert($homer);
    }

    leaktest();

    {
      my $storage = $store;
      my ($homer) = $storage->get($homer_oid);

      is_deeply($homer->{opinions},
                { work => 'bad',
                  food => 'good',
                  beer => 'better',
                  sex => 'good'});

      delete $homer->{opinions}->{work};
      $storage->insert($homer);
    }

    leaktest();

    {
      my $storage = $store;
      my ($homer) = $storage->get($homer_oid);

      is_deeply($homer->{opinions},
                { food => 'good',
                  beer => 'better',
                  sex => 'good' });

      $homer->{opinions}->{'sex'} = 'fun';
      $storage->insert($homer);
    }

    leaktest();

    {
      my $storage = $store;
      my ($homer) = $storage->get($homer_oid);

      is_deeply($homer->{opinions},
                { food => 'good',
                  beer => 'better',
                  sex => 'fun' });

      delete $homer->{opinions};
      $storage->insert($homer);
    }

    leaktest();

    {
      my $storage = $store;
      my ($homer) = $storage->get($homer_oid);

      is_deeply($homer->{opinions}, undef);

      $homer->{opinions} = { work => 'bad',
                             food => 'good',
                             beer => 'better' };
      $storage->insert($homer);
	
    }

    leaktest();

    # prefetch

    {
      my $storage = $store;

      my $homer = $storage->get($homer_oid);
      {
        local ($storage->{db});
        is_deeply($homer->{opinions},
                  { work => 'bad',
                    food => 'good',
                    beer => 'better' });
      }
    }

    leaktest();

    #    {
    #      my $storage = $store;

    #      my ($remote) = $storage->remote('NaturalPerson');
    #      $storage->prefetch($remote, 'opinions', $remote->{firstName} eq 'Homer');

    #      my ($homer) = $storage->select($remote, $remote->{firstName} eq 'Homer');

    #      {
    #        local ($storage->{db});
    #        is_deeply($homer->{opinions},
    #                  { work => 'bad',
    #                    food => 'good',
    #                    beer => 'better' });
    #      }
    #    }

    #    leaktest();
  }
}
