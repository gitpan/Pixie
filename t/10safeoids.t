#!perl -w

package SafeOIDTest;

use Pixie;

use lib 't';
use Test::Class;
use base qw/Test::Class/;
use Test::More;

sub new {
  my $proto = shift;
  my $self = $proto->SUPER::new;

  $self->{pixie} = Pixie->new->connect(@_);
  return $self;
}

sub set_up : Test(setup => 1) {
  my $self = shift;
  isa_ok($self->{pixie}, 'Pixie') or die "Not a valid pixie";
}

sub basic : Test(6) {
  my $self = shift;
  my $p = $self->{pixie};

  my $easy = SimpleArray->new(1,2,3);
  ok ! $easy->px_is_managed;
  my $oid = $p->insert($easy);
  ok $oid;
  ok $easy->px_is_managed;
  my $easy_copy = bless($easy->px_as_rawstruct, 'SimpleArray');
  undef $easy;
  $easy = $p->get($oid);
  ok $easy->px_is_managed;
  is $easy->PIXIE::oid, $oid;
  is_deeply $easy, $easy_copy;
}

package SimpleArray;

sub new {
  my $proto = shift;
  bless [ @_ ], $proto;
}

sub UNIVERSAL::px_is_managed {
  my $self = shift;
  defined($self->PIXIE::get_info->the_container);
}



package main;
my @specs = qw/memory bdb:objects.bdb/;
push @specs, split / +/, $ENV{PIXIE_TEST_STORES} if $ENV{PIXIE_TEST_STORES};

my @testers;
foreach my $storage ( @specs ) {
  eval {
    my $tester = SafeOIDTest->new( $storage );
    push @testers, $tester if $tester;
  };
}

Test::Class->runtests( @testers );
