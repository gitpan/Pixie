#!perl -w

##
## Make sure the PODs don't contain invalid markup
## (Use podlint to find the actual POD error)
##

use lib 't/lib';
use blib;
use strict;

use Test::More;

our @files;

BEGIN {
  eval "use File::Find::Rule";
  plan skip_all => "File::Find::Rule not installed." if ($@);
  eval "use Test::Pod";
  plan skip_all => "Test::Pod not installed." if ($@);
}

@files = File::Find::Rule->file()->name('*.pm', '*.pod')->in('blib/lib');
plan tests => scalar @files;

foreach my $file ( @files ) {
  # Pod::Test no loger supports 'NO_POD' test :-/
  if ( contains_pod( $file ) ) {
    pod_file_ok($file);
  } else {
  TODO: {
      local $TODO = "No pod for $file";
      fail($file);
    }
  }
}

# nicked from Module::Build::Base:
sub contains_pod {
  my $file = shift;
  return '' unless -T $file;  # Only look at text files

  open(FH, $file) or die "Can't open $file: $!";
  while (my $line = <FH>) {
    return 1 if $line =~ /^\=(?:head|pod|item)/;
  }

  return '';
}
