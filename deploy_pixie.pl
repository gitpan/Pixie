#!perl

use Pixie::Store::DBI;

my($spec, $user, $pass) = @ARGV;

Pixie::Store::DBI->deploy($spec, $user, $pass);
