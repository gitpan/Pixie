#!perl -w

##
## Pixie deep tests using Test::Class
##

use lib 't/lib';
use blib;
use strict;

use Test::Class;

use Common;

my @testers = grep defined, map DeepTest->new($_), Common->test_stores;
Test::Class->runtests(@testers);


package DeepTest;

use strict;
use Pixie;
use Test::More;

use lib 't';
use blib;
use Sunnydale;
sub Human::best_friend { $_[0]->{best_friend} }

use Test::Class;
use base qw/Test::Class/;

sub new {
  my $proto = shift;
  my $self  = $proto->SUPER::new;

  $self->{pixie_spec} = shift;
  eval {
      $self->{pixie} = Pixie->new->connect($self->{pixie_spec})
	  or die "Can't connect to pixie";
  };
  if ($@) { return undef }
  return $self;
}

sub leak_test : Test(teardown => 2) {
  my $self = shift;
  Sunnydale::leaktest;
  is $self->{pixie}->cache_size, 0, "Cache Leak";
}

sub UNIVERSAL::px_is_managed {
  my $self = shift;
  defined($self->PIXIE::get_info->pixie);
}

sub test_01 : Test(3) {
  my $self = shift;
  my $p = $self->{pixie};

  my $buffy =       Human->new(
                               name => 'Buffy',
                               best_friend =>
                               Human->new(
                                          name => 'Willow',
                                          best_friend =>
                                          Human->new(name => 'Tara')));
  ok ! $buffy->px_is_managed;

  $self->{oid}{Buffy} = $p->insert($buffy);
  ok($self->{oid}{Buffy}, "Inserted 'deep' Buffy");
  ok $buffy->px_is_managed;
}

sub test_02 : Test(12) {
  my $self = shift;
  my $p = $self->{pixie};
  my %OID = %{$self->{oid}};

  ok my $buffy = $p->get($OID{Buffy}), "Fetched buffy"
    or die $p->as_string, "Couldn't fetch Buffy";
  ok $buffy->px_is_managed;
  ok $buffy->best_friend->px_is_managed, "Proxies are managed";
  isa_ok($buffy->best_friend, 'Pixie::Proxy');
  is(($buffy->best_friend . " Rosenburg"), 'Willow Rosenburg', "Willow's name");
  ok $buffy->best_friend, "Willow is true";
  ok $buffy->best_friend->px_is_managed;
  is $buffy->best_friend->best_friend->name, 'Tara', "Willow likes Tara";
  ok $buffy->best_friend->px_is_managed;
  ok $buffy->best_friend->best_friend->px_is_managed;
  is $buffy->best_friend->name, 'Willow', "Buffy likes Willow";
  ok 1, "Pause for debugging";
}

sub test_03 : Test(4) {
  my $self = shift;
  my $p = $self->{pixie};
  my %OID = %{$self->{oid}};

  ok my $buffy = $p->get($OID{Buffy}), "Fetched buffy again"
    or die "Couldn't fetch Buffy";
  ok $buffy->px_is_managed;
  # Save it again!
  ok $p->insert($buffy), 'Resave, lazily with proxies';
  ok 1, "Pause for more debugging";
}

