#!perl -w

use strict;
use Test::More;
use Test::Exception;
use Pixie;

use lib 't';
use Sunnydale;

use Pixie::Store::DBI;
use Pixie::Store;
use Pixie::LockStrat::Exclusive;
use Pixie::LockStrat::ReadOnly;


sub FakePixie::_oid {
  my $self = shift;
  $self->{_oid};
}

sub make_a_pixie { Pixie->new->connect(shift) }

my @specs = split / +/, $ENV{PIXIE_TEST_STORES} if $ENV{PIXIE_TEST_STORES};

if (@specs) {
  plan tests => (50 * @specs);
}
else {
  plan skip_all => "No Locking stores specified";
}

for my $spec (@specs) {
 SKIP: {
    my $store;
    my $p1 = bless { _oid => 1 }, 'FakePixie';
    my $p2 = bless { _oid => 2 }, 'FakePixie';

    eval { $store = Pixie::Store->connect($spec) }
      or skip("Can't connect to $spec", 41);
    $store->{dbh}->do(q{DELETE FROM px_lock_info}); # Make sure things are tidy.

    lives_ok { $store->lock_object_for(1,$p1) } "Lock succeeds for p1";
    dies_ok { $store->lock_object_for(1,$p2) } "Lock fails for p2";
    dies_ok { $store->unlock_object_for(1, $p2) } "Unlock fails for p2";
    lives_ok { $store->unlock_object_for(1, $p1) } "Unlock succeeds for p1";
    lives_ok { $store->unlock_object_for(1, $p2) }
      "p2 can unlock now, even without a lock";
    lives_ok { $store->lock_object_for(1, $p2) }
      "p2 can lock";

    # Now, with real pixies
    $p1 = make_a_pixie($spec);
    $p2 = make_a_pixie($spec);
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

    ok( ($oid = make_a_pixie($spec)->
         insert(Vampire->new->sire(Vampire->new->name('Darla'))
                            ->name('Angel')
                            ->has_soul(1))), 
        "Set up Angel");

    my $strategy = Pixie::LockStrat::Exclusive->new;
    ok $strategy, "Set up exclusive lock";

    $p1 = make_a_pixie($spec);
    $p2 = make_a_pixie($spec);

    my $angel1 = $p1->get_with_strategy($oid, $strategy);
    ok $angel1, "Got an Angel";
    is $p1->store->locker_for($oid), $p1->_oid, "Locked by p1";
    is $p2->store->locker_for($oid), $p1->_oid, "Still locked by p1";
    my $angel2;
    lives_ok { $angel2 = $p2->get($oid) } "Null strategy is readonly";

    is $angel1->px_oid, $angel2->px_oid, "Different Pixies, same Angel OID";

    ok $angel1->PIXIE::address != $angel2->PIXIE::address,
      "Different PIXIEs, different fetched objects";
    dies_ok { $p2->insert($angel2) }
      "You can't insert an object without the lock";
    
    $angel1->sire->px_restore;
    is $p2->store->locker_for($angel2->sire), $p1->_oid,
      "Locking is 'inherited' through the object graph";
    ok $angel2->sire->px_restore;
    dies_ok { $p2->insert($angel2->sire) }
      "You still can't insert without the lock";

    # Reset again.
    lives_ok { undef $_ for ($p1, $p2, $angel2, $angel1) };

    ok $p1 = make_a_pixie($spec)->lock_strategy($strategy);
    ok $p2 = make_a_pixie($spec)->lock_strategy($strategy);

    
    ok $angel1 = $p1->get($oid);
    dies_ok { $angel2 = $p2->get($oid) };

    # Reset again.
    lives_ok { undef $_ for ($p1, $p2, $angel2, $angel1) };

    ok $p1 = make_a_pixie($spec)->lock_strategy(Pixie::LockStrat::ReadOnly->new);
    ok $angel1 = $p1->get($oid);
    throws_ok { $p1->insert($angel1) }
      qr/object is read only/i;

    # Setup a named object
    ok 1, "Setting up a named object";
    ok $p1 = make_a_pixie($spec)
      ->lock_strategy(Pixie::LockStrat::Exclusive->new);
    my $pix_oid = $p1->_oid;
    ok $angel1 = $p1->get($oid);
    ok $p1->bind_name(Angel => $angel1);
    1;
    ok $p2 = make_a_pixie($spec)
      ->lock_strategy(Pixie::LockStrat::Exclusive->new);
    throws_ok { $p2->get_object_named('Angel') }
      qr/Lock is held by $pix_oid/;
    lives_ok { $p2->get_object_named('Angel',
				     Pixie::LockStrat::ReadOnly->new) };
    1;

    undef $angel1;
    undef $angel2;
    undef $p1;
    undef $p1;
    $p1 = make_a_pixie($spec)
      ->lock_strategy(Pixie::LockStrat::Exclusive->new);
    eval {
      ok $angel1 = $p1->get_object_named('Angel');
      $p1->clear_store(undef);
      undef $p1;
      undef $angel1;
    };
    $p1 = make_a_pixie($spec)
      ->lock_strategy(Pixie::LockStrat::Exclusive->new);
    lives_ok {$angel1 = $p1->get_object_named('Angel')}
      "Store releases all its locks on DESTROY";

  }
}

