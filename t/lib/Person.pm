package Person;

sub new {
  my $class = shift;
  bless {}, $class;
}

sub birthday {
  my $self = shift;
  if (@_) {
    $self->{birthday} = shift;;
    return $self;
  } else {
    return $self->{birthday};
  }
}

sub official_birthday {
  my $self = shift;
  if (@_) {
    $self->{official_birthday} = shift;;
    return $self;
  } else {
    return $self->{official_birthday};
  }
}

sub name {
  my $self = shift;
  if (@_) {
    $self->{name} = shift;;
    return $self;
  } else {
    return $self->{name};
  }
}

sub age {
  my $self = shift;
  if (@_) {
    $self->{age} = shift;;
    return $self;
  } else {
    return $self->{age};
  }
}

sub coding_pair {
  my $self = shift;
  if (@_) {
    $self->{coding_pair} = shift;;
    return $self;
  } else {
    return $self->{coding_pair};
  }
}

1;
