#!perl -w

use strict;

use Test::More tests => 129;

use lib 't';
use blib;

use Sunnydale;
use Pixie;

#BEGIN { use_ok 'Pixie::Name' }

for (qw/memory bdb:objects.bdb dbi:mysql:dbname=test/) {
  run_tests($_);
}

sub run_tests {
  my $store_spec = shift;

 SKIP:
  {
    my $pixie = eval { Pixie->new->connect($store_spec) };

    if ($@) {
#      warn $@;
      skip "Can't load $store_spec store", 43;
    }
    $pixie->store->clear;

    my %OID;
    # Set up a simple name;
    {
      my $buffy = Human->new(first_name => 'Buffy',
                              name => 'Summers');
      ok $OID{Buffy} = $pixie->insert($buffy);
      ok $buffy->px_is_managed;
      ok $pixie->bind_name('The Slayer' => $buffy);
    }
    Sunnydale::leaktest;

    {
      ok defined(my $buffy1 = $pixie->get_object_named('The Slayer'));
      ok $buffy1->px_is_managed;
      ok defined(my $buffy2 = $pixie->get($OID{Buffy}));
      ok $buffy2->px_is_managed;
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
      ok ! $angel->px_is_managed;
      ok my $name = $pixie->bind_name('The Vampire with a Soul' =>
                                      $angel);
      ok $angel->px_is_managed;
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
      ok ! $_->px_is_managed for ($willow, $xander, $anya, $tara);
      $scooby_name = $pixie->bind_name('The Scooby Gang' =>
                        $willow, $xander, $anya, $tara);
      ok $_->px_is_managed for ($willow, $xander, $anya, $tara);
    }
    Sunnydale::leaktest;

    # And retrieve them?
    {
      my @scoobies = $pixie->get_object_named('The Scooby Gang');
      is scalar(@scoobies), 4;
      ok $_->px_is_managed for @scoobies;
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
      ok $buffy->px_is_managed;
      ok $pixie->unbind_name('The Slayer');
      my $should_be_undef = $pixie->get_object_named('The Slayer');
      is $should_be_undef, undef;
      ok defined $buffy;
    }
    Sunnydale::leaktest;

    {
      my $buffy = $pixie->get($OID{Buffy});
      ok defined $buffy;
      ok $buffy->px_is_managed;
      isa_ok $buffy, 'Human';
    }
    Sunnydale::leaktest;
  }
}
