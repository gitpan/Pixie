package Pixie::Store::DBI;

use DBI;
use DBIx::AnyDBD;

use base Pixie::Store;

use Pixie::Store::DBI::Default;
sub connect { &Pixie::Store::DBI::Default::connect };

1;
