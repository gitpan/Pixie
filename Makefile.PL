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

WriteMakefile (
  NAME         => 'Pixie',
  VERSION_FROM => 'lib/Pixie.pm',
  ABSTRACT     => 'Pixie is an object oriented database, written in Perl',
  PREREQ_PM    => {
		   Scalar::Util      => 0.01,
		   Test::Simple      => 0.01,
		   DBIx::AnyDBD      => 0,
		   Data::UUID        => 0.01,
		   Test::Class       => 0.03,
    	          },
);
