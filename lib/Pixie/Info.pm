package Pixie::Info;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA       = qw(Exporter DynaLoader);
@EXPORT    = qw( );
@EXPORT_OK = qw(px_get_info px_set_info);
$VERSION   = '2.08_02';

bootstrap Pixie::Info $VERSION;

1;

__END__

=head1 NAME

Pixie::Info - A magical way of having out of band info

=head1 SYNOPSIS

  use Pixie::Info;

  $obj->Pixie::Info::set_info($a_value);
  ...
  $info = Pixie::Info::get_info($obj) # could use OO style here too...

=head1 DESCRIPTION

Associates an id (could be an object itself) to any other object or
ref.  if you destroy the ref and you dont hold any copy of $id, $id
gets also destroyed.

Be carefully about circular references (C<Scalar::Util::weaken> is
your friend.

=head1 AUTHOR

M. Friebe

Converted to Pixie by Piers Cawley (changed the magic type, module
name, stole the idea).

=cut
