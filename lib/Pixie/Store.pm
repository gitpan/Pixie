package Pixie::Store;

use strict;
our $VERSION = '2.01';
my %typemap = ( memory => 'Pixie::Store::Memory',
                bdb => 'Pixie::Store::BerkeleyDB',
                dbi => 'Pixie::Store::DBI', );

sub connect {
  my $proto = shift;
  my($type, $path) = split(':', shift, 2);

  $type = lc($type);
  die "Invalid database spec" unless exists $typemap{$type};

  eval "require " . $typemap{$type};
  die $@ if $@;

  $typemap{$type}->connect($path,@_);
}

1;
