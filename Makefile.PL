use warnings;
use warnings::register;
use ExtUtils::MakeMaker;

eval {
  require 5.008;
};
if ($@) {
  warnings::warn("Pixie requires perl 5.8.0.");
  exit;
}

eval { require Data::Dumper; };
if ($@) {
  warnings::warn("Pixie requires Data::Dumper");
  exit;
}
unless (defined &Data::Dumper::Dumpxs) {
  warnings::warn("Pixie requires a working Data::Dumper::Dumpxs");
  exit;
}

unless ($ENV{PIXIE_TEST_STORES}) {
  warn <<'EOW';
You have not set the PIXIE_TEST_STORES environment variable. If you want
Pixie to run its tests against any RDBMSes you may have installed. To run
those tests you should set PIXIE_TEST_STORES with a series of space
separated DBI specifiers which pixie will run tests against

EOW

#  Pixie will create three tables in each of the databases specified,
#  'px_object', 'px_lock_info' and 'px_rootset'; and these tables will
#  emptied multiple times during the test run. Do not run the tests on
#  a 'live' pixie database.

#  EOW
}

WriteMakefile (
  NAME         => 'Pixie',
  VERSION_FROM => 'lib/Pixie.pm',
  ABSTRACT     => 'Pixie is an object oriented database, written in Perl',
  PREREQ_PM    => {
		   Scalar::Util      => 0.01,
		   Test::Simple      => 0.01,
		   DBIx::AnyDBD      => 2.01,
		   Data::UUID        => 0.01,
		   Test::Class       => 0.03,
    	          },
);
