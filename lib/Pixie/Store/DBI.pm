package Pixie::Store::DBI;

use DBI;
use DBIx::AnyDBD;

our $VERSION = '2.04';

use base Pixie::Store;

use Pixie::Store::DBI::Default;
sub connect { &Pixie::Store::DBI::Default::connect }
sub deploy { &Pixie::Store::DBI::Default::deploy }
sub _raw_connect { &Pixie::Store::DBI::Default::_raw_connect }
1;
