package My::Time::Date;

sub new {
  my $class = shift;
  bless {}, $class;
}

sub date {
  my $self = shift;
  my $date = shift;
  if (defined($date)) {
    $self->{date} = $date;
    return $self;
  } else {
    return $self->{date};
  }
}

1;
