#!perl -w

use lib '../lib';

use Test::More tests => 8;
use Pixie;

my $t = non_hash->new->key1('Wibble')
                     ->key2(non_hash->new->key1('foo')->key2('bar'));
my $p = Pixie->new();
ok(my $oid = $p->insert( $t ), "inserted non-hash");
$t = undef;

ok(my $f = $p->get($oid));

is($f->key1, 'Wibble');
isa_ok($f->key2, 'Pixie::Proxy');
isa_ok($f->key2, 'non_hash');

is($f->key2->key1, 'foo');
is($f->key2->key2, 'bar');

ok(!$f->key2->isa('Pixie::Proxy'));

package non_hash;

sub new {
  my $proto = shift;
  return bless [], $proto;
}

my $_oid = 0;
sub _oid {
  my $self = shift;
  $self->[2] ||= ++$_oid;
}

sub key1 {
  my $self = shift;
  if(@_) {
    my $val = shift;
    $self->[0] = $val;
    return $self;
  }
  else {
    return $self->[0];
  }
}

sub key2 {
  my $self = shift;
  if(@_) {
    my $val = shift;
    $self->[1] = $val;
    return $self;
  }
  else {
    return $self->[1];
  }
}
