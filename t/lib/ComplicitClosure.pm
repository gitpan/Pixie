package ComplicitClosure;

use base 'Closure';

sub px_is_storable { 1 };

sub px_freeze {
  my $self = shift;
  bless { $self->px_dump_state }, ComplicitClosure::Memento;
}

sub px_dump_state {
  my $self = shift;
  $self->($self, '_dump_state');
}


package ComplicitClosure::Memento;

sub px_thaw {
  my $self = shift;
  ComplicitClosure->new(%$self);
}

sub px_is_immediate { 1 };

1;
