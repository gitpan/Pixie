##
## Tests for Postgres Pixie Stores
##

package StoreTests::Pg;

use strict;
use warnings;

use Test::More;
use Test::Exception;

use base qw( StoreTests::DBI );

sub is_named_table_in {
    my $self   = shift;
    my $name   = shift;
    my @tables = @_;
    scalar grep {/^(?:public\.)?$name$/i} @tables;
}

1;
