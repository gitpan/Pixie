use strict;

package SpringfieldObject;

use vars qw/$pop/;

sub new {
  my $proto = shift;
  ++$pop;
  return bless { $proto->defaults, @_ }, $proto;
}

sub defaults { return () }

sub DESTROY { --$pop }

package Person;

use vars qw( @ISA );

@ISA = 'SpringfieldObject';

sub as_string
{
   die 'subclass responsibility';
}

#use overload '""' => sub { shift->as_string }, fallback => 1;

package NaturalPerson;

use vars qw( @ISA );

@ISA = 'Person';

sub defaults
{
   a_children => [], ia_children => [],
   h_opinions => {}
}

sub as_string
{
   my ($self) = @_;
        local $^W; # why? get use of undefined value otherwise
   exists($self->{name}) && exists($self->{firstName}) && "$self->{firstName} $self->{name}"
        || $self->{firstName} || $self->{name}
}

package LegalPerson;

use vars qw( @ISA );

@ISA = 'Person';

sub as_string
{
   return shift->{name};
}

package NuclearPlant;

use vars qw( @ISA );

@ISA = 'LegalPerson';

package Opinion;
use base qw( SpringfieldObject );

package Credit;
use base qw( SpringfieldObject );

package Item;
use base qw( SpringfieldObject );

1;
