#!perl -w

use strict;
use Test::More tests => '45';
use Test::Exception;
use Pixie;

use lib 't';
use Sunnydale;

BEGIN {
  use_ok 'Pixie::Store::DBI';
  use_ok 'Pixie::Store';
  use_ok 'Pixie::LockStrat::Exclusive';
  use_ok 'Pixie::LockStrat::ReadOnly';
}

sub FakePixie::_oid {
  my $self = shift;
  $self->{_oid};
}

sub make_a_pixie { Pixie->new->connect('dbi:mysql:dbname=test') }

my $p1 = bless { _oid => 1 }, 'FakePixie';
my $p2 = bless { _oid => 2 }, 'FakePixie';

SKIP: {
  my $store;
  eval { $store = Pixie::Store->connect('dbi:mysql:dbname=test') }
    or skip("Can't connect to dbi:mysql:dbname=test", 41);
  $store->{dbh}->do(q{DELETE FROM lock_info}); # Make sure things are tidy.

  lives_ok { $store->lock_object_for(1,$p1) };
  dies_ok { $store->lock_object_for(1,$p2) };
  dies_ok { $store->unlock_object_for(1, $p2) };
  lives_ok { $store->unlock_object_for(1, $p1) };
  lives_ok { $store->unlock_object_for(1, $p2) };
  lives_ok { $store->lock_object_for(1, $p2) };

  # Now, with real pixies

  $p1 = make_a_pixie;
  $p2 = make_a_pixie;
  my $simple = bless { foo => 'bar' }, 'Simple';
  my $oid = $p1->insert($simple);

  lives_ok { $p1->lock_object($simple) }      "Simple lock";
  lives_ok { $p1->unlock_object($simple) }    "Simple unlock" ;
  throws_ok { $p2->lock_object($simple) } 
    qr/object is not managed by this pixie/i, "Locker must own object";
  throws_ok { $p2->unlock_object($simple) }
    qr/object is not managed by this pixie/i, "unlocker must own object";
  ok my $simple2 = $p2->get($oid),            "Get a duplicate object";
  lives_ok { $p2->lock_object($simple2) }     "Lock the duplicate";
  dies_ok { $p1->lock_object($simple) };
  undef($simple2);
  lives_ok { $p1->lock_object($simple) }      "Object is unlocked on DESTROY";
  $simple2 = $p2->get($oid);
  dies_ok { $p2->lock_object($simple2) };
  $simple2->{foo} = 'baz';
  dies_ok { $p2->insert($simple2) }           "Can't insert if locked elsewhere";
  undef $simple2;
  ok $simple2 = $p2->get($oid);
  is_deeply $simple2, $simple,                "We have 'the same' object";
  ok $simple->PIXIE::address !=
    $simple2->PIXIE::address,                 "But not the *same* object";
  undef($p1);
  lives_ok { $p2->lock_object($simple2) }     "Object unlocked on Pixie::DESTROY";

  # Clean up.
  undef $_ for ($p1, $p2, $simple, $simple2);

  # And now, with LockingStrategy objects

  # First, set up a 'complex' object;

  ok $oid = make_a_pixie()->
    insert(Vampire->new->sire(Vampire->new->name('Darla'))
                       ->name('Angel')
                       ->has_soul(1));

  ok my $strategy = Pixie::LockStrat::Exclusive->new;

  $p1 = make_a_pixie();
  $p2 = make_a_pixie();

  ok my $angel1 = $p1->get_with_strategy($oid, $strategy);
  is $p1->store->locker_for($oid), $p1->_oid;
  is $p2->store->locker_for($oid), $p1->_oid;
  my $angel2;
  lives_ok { $angel2 = $p2->get($oid) } "Null strategy is readonly";

  is $angel1->px_oid, $angel2->px_oid;
  ok $angel1->PIXIE::address != $angel2->PIXIE::address;
  dies_ok { $p2->insert($angel2) };
  $angel1->sire->px_restore;
  is $p2->store->locker_for($angel2->sire), $p1->_oid;
  ok $angel2->sire->px_restore;
  dies_ok { $p2->insert($angel2->sire) };

  # Reset again.
  lives_ok { undef $_ for ($p1, $p2, $angel2, $angel1) };

  ok $p1 = make_a_pixie()->lock_strategy($strategy);
  ok $p2 = make_a_pixie()->lock_strategy($strategy);

  ok $angel1 = $p1->get($oid);
  dies_ok { $angel2 = $p2->get($oid) };

  # Reset again.
  lives_ok { undef $_ for ($p1, $p2, $angel2, $angel1) };

  ok $p1 = make_a_pixie()->lock_strategy(Pixie::LockStrat::ReadOnly->new);
  ok $angel1 = $p1->get($oid);
  throws_ok { $p1->insert($angel1) }
    qr/object is read only/i;
}


