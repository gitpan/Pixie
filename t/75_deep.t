#!perl -w

##
## Pixie::Name tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More;

use Common;
use Sunnydale;

use Pixie;

plan tests => 12 * Common->test_stores;

run_tests($_) for Common->test_stores;

sub Human::best_friend { $_[0]->{best_friend} }

sub run_tests {
  my $store_spec = shift;

  SKIP:
  {
    my $p = eval { Pixie->new->connect($store_spec) };
    if ($@) {
      skip "Can't load $store_spec store", 12;
    }

    $p->clear_storage;
    ok 1, "Starting test of $store_spec";

    my %OID;
    {
      ok $OID{Buffy} = $p->insert
          (
           Human->new(name => 'Buffy',
                      best_friend =>
                      Human->new(name => 'Willow',
                                 best_friend =>
                                 Human->new(name => 'Tara')
                                )
                     )
          ), "Setup 'deep' object" ;
    }
    Sunnydale::leaktest;

    {
      ok my $buffy = $p->get($OID{Buffy});
      is(($buffy->best_friend . " Rosenburg"), 'Willow Rosenburg', "Willow's name");
      ok $buffy->best_friend, "Willow is true";
      is $buffy->best_friend->best_friend->name, 'Tara';
      is $buffy->best_friend->name, 'Willow';
    }
    Sunnydale::leaktest;

    {
      ok my $buffy = $p->get($OID{Buffy});
      # Save it again!
      ok $p->insert($buffy), 'Resave, lazily with proxies';
    }
    Sunnydale::leaktest;
  }
}
