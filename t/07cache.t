#!perl -w

use strict;

use Test::More;
use lib 't';
use blib;
use Sunnydale;

use Pixie;

use Test::More tests => 72;

for (qw/memory bdb:objects.bdb dbi:mysql:dbname=test/) {
  run_tests($_);
}

sub run_tests {
  my $store_spec = shift;

  SKIP:
  {
    my $pixie = eval { Pixie->new->connect($store_spec) };
    if ($@) {
      warn $@;
      skip "Can't load $store_spec store", 24;
    }
    $pixie->store->clear;
    ok 1, "Starting test of $store_spec";

    my %OID;
    {
      my $buffy = Human->new(first_name => 'Buffy',
                             name => 'Summers',);
      ok $OID{Buffy} = $pixie->insert($buffy);
      is $buffy->_oid, $OID{Buffy};
    }

    Sunnydale::leaktest;

    {
      ok my $buffy1 = $pixie->get($OID{Buffy});
      ok my $buffy2 = $pixie->get($OID{Buffy});
      $buffy1->{is_slayer} = 1;
      is $buffy2->{is_slayer}, $buffy1->{is_slayer};
    }
    Sunnydale::leaktest;

    {
      ok defined(my $buffy = $pixie->get($OID{Buffy}));
      my $giles = Human->new(name => 'Giles');
      is "$giles", "Giles", "Simple overload";
      $buffy->{watcher} = $giles;
      my $willow = Human->new(first_name => 'Willow',
                              name => 'Rosenberg');
      $willow->{mentor} = $giles;
      ok $OID{Willow} = $pixie->insert($willow);
      is $OID{Buffy}, $pixie->insert($buffy);
    }
    Sunnydale::leaktest;

   {
      ok defined(my $giles = $pixie->get($OID{Buffy})->{watcher});
      ok defined(my $willow = $pixie->get($OID{Willow}));
      isa_ok $giles, 'Human';
      isa_ok $giles, 'Pixie::Proxy';
      $giles->first_name('Rupert');
      is "$giles", "Rupert Giles";
      is $giles . "1", "Rupert Giles1";
      ok !$willow->{mentor}->isa('Pixie::Proxy');
      is $willow->{mentor}->first_name, 'Rupert';
      is "$willow->{mentor}", 'Rupert Giles';
      ok $OID{Giles} = $pixie->insert($giles);
    }

    Sunnydale::leaktest;
  }
}




