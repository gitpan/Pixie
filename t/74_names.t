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

plan tests => 24 * Common->test_stores;

run_tests($_) for Common->test_stores;

sub run_tests {
  my $store_spec = shift;

 SKIP:
  {
    my $pixie = eval { Pixie->new->connect($store_spec) };

    if ($@) {
#      warn $@;
      skip "Can't load $store_spec store", 24;
    }
    $pixie->store->clear;

    my %OID;
    # Set up a simple name;
    {
      my $buffy = Human->new(first_name => 'Buffy',
			     name       => 'Summers');
      ok $OID{Buffy} = $pixie->insert($buffy);
      ok $pixie->bind_name('The Slayer' => $buffy);
    }
    Sunnydale::leaktest;

    {
      ok defined(my $buffy1 = $pixie->get_object_named('The Slayer'));
      ok defined(my $buffy2 = $pixie->get($OID{Buffy}));
      isa_ok $buffy1, 'Human';
      isa_ok $buffy2, 'Human';
      $buffy1->{is_slayer} = 1;
      is $buffy2->{is_slayer}, 1, "There's only one slayer";
    }

    Sunnydale::leaktest;

    # Name shouldn't have a 'real' reference to the object.
    {
      my $angel = Vampire->new(name => 'Angel',
                               has_soul => 1,);
      ok my $name = $pixie->bind_name('The Vampire with a Soul' =>
                                      $angel);
      push @{$angel->{aka}}, $name;
      $pixie->insert($angel);
    }
    Sunnydale::leaktest;

    # Can we name groups?
    my $scooby_name;
    {
      my $willow = Human->new(first_name => 'Willow',
                              name => 'Rosenburg');
      my $xander = Human->new(first_name => 'Xander',
                              name => 'Harris');
      my $anya = Human->new(name => 'Anya');

      my $tara = Human->new(name => 'Tara');
      $scooby_name = $pixie->bind_name('The Scooby Gang' =>
                        $willow, $xander, $anya, $tara);
    }
    Sunnydale::leaktest;

    # And retrieve them?
    {
      my @scoobies = $pixie->get_object_named('The Scooby Gang');
      is scalar(@scoobies), 4;
    }
    Sunnydale::leaktest;

    # Get a nonexistent name
    {
      my $joss = $pixie->get_object_named('Creator');
      is $joss, undef;
    }
    Sunnydale::leaktest;

    {
      my $buffy = $pixie->get_object_named('The Slayer');
      ok defined $buffy;
      ok $pixie->unbind_name('The Slayer');
      my $should_be_undef = $pixie->get_object_named('The Slayer');
      is $should_be_undef, undef;
      ok defined $buffy;
    }
    Sunnydale::leaktest;

    {
      my $buffy = $pixie->get($OID{Buffy});
      ok defined $buffy;
      isa_ok $buffy, 'Human';
    }
    Sunnydale::leaktest;
  }
}
