package Pixie::CacheManager;

use strict;

use base 'Pixie::Object';

our $VERSION = '2.03';

sub init {
  my $self = shift;
  $self->{_cache} = {};
}

1;
