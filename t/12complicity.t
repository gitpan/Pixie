#!perl -w

use lib 't';
use blib;

use Sunnydale;

package Closure;
use vars qw/$AUTOLOAD/;
use Carp;

sub new {
  my $proto = shift;
  my %state = @_;
  bless sub {
    my $self = shift;
    my $selector = shift;
    Carp::confess "Undefined selector" unless defined $selector;
    return %state if $selector eq '_dump_state';
    my($do_set, $key) = ($selector =~ /(set_)?(?:get_)?(.*)/);
    die "$selector isn't a valid method" unless exists $state{$key};

    if ($do_set) {
      $state{$key} = shift;
      return $self;
    }
    else {
      $state{$key};
    }
  }, $proto;
}


sub AUTOLOAD {
  my $self = shift;
  my($method) = ($AUTOLOAD =~ /.*::(.*)/);
  if ($method =~ /^[sg]et_/) {
    $self->($self, $method => @_);
  }
  else {
    $method = "SUPER::$method";
    $self->$method(@_);
  }
}

package ComplicitClosure;

use base 'Closure';

sub px_is_storable { 1 };

sub px_freeze {
  my $self = shift;
  bless { $self->px_dump_state }, ComplicitClosure::Memento;
}

sub px_dump_state {
  my $self = shift;
  $self->($self, '_dump_state');
}

package ComplicitClosure::Memento;

sub px_thaw {
  my $self = shift;
  ComplicitClosure->new(%$self);
}

sub px_is_immediate { 1 };

package TestComplicity;

use Test::More;
use base 'Test::Class';
use Test::Exception;

use Pixie;

sub new {
  my $proto = shift;
  my $self = $proto->SUPER::new;

  eval {
    $self->{pixie} = Pixie->new->connect($_[0])
      or return undef;# "Can't connect to pixie";
  }; if ($@) { return undef; }
  $self->{pixie}->clear_storage;
  return $self;
}

sub leak_test : Test(teardown => 2) {
  my $self = shift;
  Sunnydale::leaktest;
  ok ! $self->{pixie}->cache_size, "Cache Leak";
}

sub ensure_failure : Test(2) {
  my $self = shift;
  $p = $self->{pixie};
  throws_ok {$p->insert(Closure->new(bool => 0))}
	    qr/Pixie cannot store a Closure|Something bad happened/, "Direct closure";
  throws_ok { $p->insert(bless { closure => Closure->new(bool => 0) }, 'SimpleHash') }
	    qr/Pixie cannot store a Closure|Something bad happened/, "Indirect closure";
  1;
}

sub test_basic : Test(12) {
  my $self = shift;
  my $p = $self->{pixie};
  my $oid;
  my $closure = ComplicitClosure->new(bool => 0);
  ok $oid = $p->insert($closure), "Store!";
  undef($closure);
  $self->leak_test;
  ok $closure = $p->get($oid), "Fetch!";
  isa_ok $closure, "ComplicitClosure";
  is $closure->get_bool, 0;
  $closure->set_bool(1);
  ok $p->insert($closure), "Store changed object";
  undef($closure);
  $self->leak_test;
  ok $closure = $p->get($oid), "Fetch again!";
  isa_ok $closure, "ComplicitClosure";
  is $closure->get_bool, 1;
}

sub test_nested : Test(13) {
  my $self = shift;
  my $p = $self->{pixie};
  ok my $oid = $p->insert(bless { a_key => 0,
				  b_key => ComplicitClosure->new(foo => 0) }, 'Simple');
  ok my $obj = $p->get($oid);
  isa_ok $obj, 'Simple';
  isa_ok $obj->{b_key}, 'ComplicitClosure';
  is $obj->{b_key}->get_foo, 0;
  $obj->{b_key}->set_foo(Human->new(name => 'Buffy'));
  ok $p->insert($obj);
  undef($obj);
  $self->leak_test;
  ok $obj = $p->get($oid), "Refetched, with Buffy";;
  isa_ok $obj->{b_key}, 'ComplicitClosure';
  isa_ok $obj->{b_key}->get_foo, 'Human';
  isa_ok $obj->{b_key}->get_foo, 'Pixie::Proxy';
  is $obj->{b_key}->get_foo->name, 'Buffy';
}

sub test_aliasing : Test(8) {
  my $self = shift;
  my $p = $self->{pixie};

  my($oid1, $oid2);
  {
    my $closure = ComplicitClosure->new(foo => 'bar');
    ok $oid1 = $p->insert(bless { closure => $closure }, 'Simple');
    ok $oid2 = $p->insert(bless { closure => $closure }, 'Simple');
  }
  $self->leak_test;
  {
    ok my $obj1 = $p->get($oid1);
    ok my $obj2 = $p->get($oid2);
    is $obj1->{closure}, $obj2->{closure};
    $obj1->{closure}->set_foo('foo');
    is $obj2->{closure}->get_foo, 'foo';
  }
}

package main;

my @testers = grep defined, map TestComplicity->new($_),
		      qw/memory dbi:mysql:dbname=test bdb:objects.bdb/;
Test::Class->runtests(@testers);


