=head1 NAME

Pixie::Store::DBI -- abstract class for DBI-based Pixie stores.

=head1 SYNOPSIS

  use Pixie;

  my $dsn;   # see subclasses for valid dsn specs
  my %args = ( user => 'foo', pass => 'bar' );

  Pixie->deploy( $dsn, %args );  # only do this once

  my $px = Pixie->new->connect( $dsn );

=head1 DESCRIPTION

Abstract class for DBI-based Pixie stores.  See subclasses for implemented
DBI stores.

=cut

package Pixie::Store::DBI;

use DBI;
use DBIx::AnyDBD;
use Pixie::Store::DBI::Default;

our $VERSION = "2.08_02";

sub connect      { &Pixie::Store::DBI::Default::connect( @_ ) }
sub deploy       { &Pixie::Store::DBI::Default::deploy( @_ )  }
sub _raw_connect { &Pixie::Store::DBI::Default::_raw_connect( @_ ) }

1;

__END__

=head1 KNOWN SUBCLASSES

=over 2

=item *
L<Pixie::Store::DBI::SQLite>

=item *
L<Pixie::Store::DBI::Mysql>

=item *
L<Pixie::Store::DBI::Pg>

=back

=head1 SEE ALSO

L<Pixie>, L<Pixie::Store>, L<DBIx::AnyDBD>

=head1 AUTHORS

James Duncan <james@fotango.com>, Piers Cawley <pdcawley@bofh.org.uk>
and Leon Brocard <acme@astray.com>.

Docs by Steve Purkis <spurkis@cpan.org>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Fotango Ltd

This software is released under the same license as Perl itself.

=cut
