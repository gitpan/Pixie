package Closure;

use strict;
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

# AUTOLOAD attempts to call DESTROY on exit, warnings if this doesn't exist:
sub DESTROY {}

1;
