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

package main;

use Test::More;

eval "use BerkeleyDB";

if ($@) {
  plan skip_all => "BerkeleyDB won't load.";
  exit;
}
else {
  plan tests => 6;
}


my $a = bless(
	      {
	       name => 'James',
	       age  => '22',
	       birthday => My::Time::Date->new()->date( '27/05/1979' ),
	      }, 'Person'
	     );

my $i = 0;
my $p = Pixie->connect('bdb:objects.bdb');
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
