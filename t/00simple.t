#!perl -w

use lib '../lib';

use Pixie;
use Data::Dumper;

package My::Time::Date;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
}

sub date {
  my $self = shift;
  my $date = shift;
  if (defined($date)) {
    $self->{date} = $date;
    return $self;
  } else {
    return $self->{date};
  }
}


package Person;

sub birthday { $_[0]->{birthday} }

package main;



use Test::More;
use Test::Exception;

my @specs = qw/memory bdb:objects.bdb/;
push @specs, split / +/, $ENV{PIXIE_TEST_STORES} if $ENV{PIXIE_TEST_STORES};

plan tests => 18 * @specs;

for my $store_spec (@specs) {
  SKIP: {
    my $p = eval {Pixie->new->connect($store_spec)};

    if ($@) {
      warn $@;
      skip "Can't load $store_spec store", 18;
    }

    like $p->as_string, qr/Pixie:.*$store_spec/ms;

    my $james = bless({
                       name     => 'James',
                       age      => '22',
                       birthday => My::Time::Date->new()->date( '27/05/1979' ),
                      }, 'Person'
                     );

    my $piers = bless(
                      {
                       name     => 'Piers',
                       age      => '34',
                       birthday => My::Time::Date->new()->date( '15/09/1967' ),
                       coding_pair => $james,
                      }, 'Person'
                     );

    my $i = 0;
    my %oid;
    $oid{james} = $p->insert( $james );
    $oid{piers} = $p->insert( $piers );
    $oid{james_bday} = $james->birthday->PIXIE::oid;
    $james = undef;
    $piers = undef;
    ok my $pdc = $p->get($oid{piers});
    is $pdc->{coding_pair}->birthday->date, '27/05/1979';
    undef($pdc);
    ok $p->delete($oid{piers});
    ok !defined($p->get($oid{piers}));
    my $result = $p->delete($oid{piers});
    ok defined($result) && $result == 0;
    my $b = $p->get( $oid{james} )->{birthday};
    is $b->PIXIE::oid, $oid{james_bday};
    my $newtime = scalar( localtime( time() ) );
    $b->date( $newtime );
    is $p->insert( $b ), $oid{james_bday};
    $b = undef;
    my $c = $p->get( $oid{james} );
    ok($c->{birthday}->date() eq $newtime, "time is right ($newtime)");

    my $d = bless {
                   name => 'James', age => '22',
                   birthday => $c->{birthday}, official_birthday => $c->{birthday},
                  };

    ok $oid{d} = $p->insert($d);
    $d = undef;

    ok $d = $p->get($oid{d});

    is $d->{birthday}->date, $c->{birthday}->date;
    is $d->{official_birthday}->date, $d->{birthday}->date;
    $newtime = localtime(time);

    $d->{official_birthday}->date($newtime);
    is $d->{official_birthday}->date, $d->{birthday}->date;

    # Check we can save pixie itself;
    my $pix_oid;
    lives_ok { ok $pix_oid = $p->insert($p) };
    lives_ok { is_deeply $p->get($pix_oid), $p };
  }
}
