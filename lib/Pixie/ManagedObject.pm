package Pixie::ManagedObject;

our $VERSION = '2.03';

sub px_is_managed {
  1;
}

sub UNIVERSAL::px_is_managed { }

1;
