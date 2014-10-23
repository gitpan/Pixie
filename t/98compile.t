#!/usr/bin/perl -w
#
# Make sure we can "use" every module

use strict;
use vars qw(@classes);

BEGIN {
  eval {
    require File::Find::Rule;
  };
  if ($@) {
    print "1..0 # Skipped - do not have File::Find::Rule installed\n";
    exit;
  }
}


BEGIN {
  use File::Find::Rule;
  @classes = map { my $x = $_;
		   $x =~ s|^blib/lib/||;
		   $x =~ s|/|::|g;
		   $x =~ s|\.pm$||;
		   $x;
		 } File::Find::Rule->file()->name('*.pm')->in('blib/lib');
}

my $expected_classes = 22;

use Test::More;

plan tests => $expected_classes + 1;

is +@classes, $expected_classes;

foreach my $class ( @classes ) {
  use_ok( $class );
}
