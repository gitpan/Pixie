#!perl -w

##
## Pixie 'non-hash' (ie: blessed array) tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More;

use Pixie;
use Data::Dumper;

use Common;
use Person;
use My::Time::Date;

BEGIN {
  eval "use BerkeleyDB";
  plan skip_all => "BerkeleyDB won't load." if ($@);
  plan tests    => 6;
}

my $a = Person->new->name( 'James' )
	           ->age( '22' )
                   ->birthday( My::Time::Date->new->date( '27/05/1979' ) );

my $i = 0;
my $p = Pixie->connect( Common->bdb_store );
my $oid = $p->insert( $a );
$a = undef;
my $b = $p->get( $oid )->{birthday};
my $newtime = scalar( localtime( time() ) );
$b->date( $newtime );
$p->insert( $b );
$b = undef;
my $c = $p->get( $oid );
ok($c->{birthday}->date() eq $newtime, "time is right ($newtime)");

my $d = bless {
               name => 'James', age => '22',
               birthday => $c->{birthday}, official_birthday => $c->{birthday},
              };

ok $oid = $p->insert($d);
$d = undef;

ok $d = $p->get($oid);

is $d->{birthday}->date, $c->{birthday}->date;
is $d->{official_birthday}->date, $d->{birthday}->date;
$newtime = localtime(time);

$d->{official_birthday}->date($newtime);
is $d->{official_birthday}->date, $d->{birthday}->date;
