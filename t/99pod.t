#!/usr/bin/perl -w
#
# Make sure the PODs don't contain invalid markup
#
# Use podlint to find the actual POD error

use strict;
use vars qw(@files $TODO);

BEGIN {
  eval {
    require File::Find::Rule;
    require Test::Pod;
  };
  if ($@) {
    print "1..0 # Skipped - do not have Find::File::Rule or Test::Pod installed: $@\n";
    exit;
  }
}

BEGIN {
  use File::Find::Rule;
  @files = File::Find::Rule->file()->name('*.pm', '*.pod')->in('blib/lib');
}

use Test::Pod tests => scalar @files;

my %has_pod = map { my $file = "blib/lib/${_}.pm";
                    $file =~ s{::}{/}g;
                    $file => 1}
  qw(Pixie
     Pixie::Store
     Pixie::FinalMethods 
     Pixie::Complicity
     Pixie::Info
    );
     


foreach my $file ( @files ) {
  if ( ! $has_pod{$file} ) {
  TODO: { local $TODO = "No pod for $file";
          pod_ok($file);
        }
  }
  else {
    pod_ok($file, NO_POD);
  }
}
