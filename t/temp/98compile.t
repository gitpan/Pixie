#!perl -w

##
## Make sure we can "use" every module
##

use lib 't/lib';
use blib;
use strict;

use Test::More;

our $expected_classes;

BEGIN {
  eval "use File::Find::Rule";
  plan skip_all => "File::Find::Rule not installed." if ($@);

  $expected_classes = 22;
  plan tests    => $expected_classes + 1;
}

my @classes = map { my $x = $_;
		    $x =~ s|^blib/lib/||;
		    $x =~ s|/|::|g;
		    $x =~ s|\.pm$||;
		    $x;
		  } File::Find::Rule->file()->name('*.pm')->in('blib/lib');

is +@classes, $expected_classes, 'expected classes';

use_ok( $_ ) for ( @classes );
