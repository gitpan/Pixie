##
# NAME
#   Pixie::LockStrat::Null - basic locking strategy for Pixie
#
# SYNOPSIS
#   use Pixie::LockStrat::Null;
#   # see Pixie::LockStrat;
#
# DESCRIPTION
#   Exact same as Pixie::LockStrat.
#
##
package Pixie::LockStrat::Null;

use strict;

use base qw( Pixie::LockStrat );

our $VERSION = '2.08_02';

1;
