use ExtUtils::MakeMaker;

WriteMakefile (
  NAME         => 'Pixie',
  VERSION_FROM => 'lib/Pixie.pm',
  ABSTRACT     => 'Pixie is an object oriented database, written in Perl',
  PREREQ_PM    => {
		   Scalar::Util      => 0.01,
		   Test::Simple      => 0.01,
		   DBIx::AnyDBD      => 0,
		   Data::UUID        => 0.01,
		  },
);
