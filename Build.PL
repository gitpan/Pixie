#!/usr/bin/perl

=head1 NAME

Build.PL - Build script generator for C<Pixie>

=head1 SYNOPSIS

 perl Build.PL
 ./Build
 ./Build test
 ./Build install

=cut

use strict;
use warnings;
use File::Spec;
use Module::Build;

my $SUBCLASS_CODE = join( '', <DATA> );

my $class = Module::Build->subclass
  (
   class => 'Pixie::Builder',
   code  => $SUBCLASS_CODE,
  );

my $build = $class->new
  (
   module_name        => 'Pixie',
   dist_version_from  => 'lib/Pixie.pm',
   create_makefile_pl => 'passthrough',
   create_readme      => 1,
   license            => 'perl',
   requires           => {
			  'perl'          => '5.8.0',
			  'DBI'           => '1.30',
			  'Data::Dumper'  => 2.12,
			  'Scalar::Util'  => 0.01,
			  'Test::Simple'  => 0.01,
			  'DBIx::AnyDBD'  => 2.01,
			  'Data::UUID'    => 0.01,
		         },
   build_requires     => {
			  'Test::More'      => 0.01,
			  'Test::Class'     => 0.03,
			  'Test::Exception' => 0.03,
			  'Module::Build'   => 0.20,
		         },
  );

eval { require Data::Dumper; };
die "Pixie requires Data::Dumper with a working Dumpxs()" if ($@);
die "Pixie requires a working Data::Dumper::Dumpxs" unless (defined &Data::Dumper::Dumpxs);

unless ($ENV{PIXIE_TEST_STORES}) {
  warn <<'EOW';
You have not set the PIXIE_TEST_STORES environment variable.

If you want Pixie to run tests against any RDBMSes you may have installed you
should set PIXIE_TEST_STORES with a series of space-separated DBI specs, ie:

    PIXIE_TEST_STORES='dbi:mysql:dbname=test;user=test dbi:...'

Pixie will create tables with the prefix 'px_' in each of the databases given,
and will empty them as needed (so do *NOT* run the tests on a live database!).

If you do not have any RDBMSes to test against, ignore this message.

EOW
}

$build->create_build_script;


=head1 AUTHOR

Steve Purkis <spurkis@cpan.org>

Based on Pixie's original C<Makefile.PL> by Piers Cawley & James Duncan.

=cut

__DATA__

# Pixie::Builder - custom Module::Build extension
# Auto-generated from Build.PL

use strict;
use File::Spec::Functions;

sub ACTION_test {
    my $self = shift;
    $self->add_to_cleanup( catfile(qw( t tmp )) );
    $self->SUPER::ACTION_test;
}

