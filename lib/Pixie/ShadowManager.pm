package Pixie::ShadowManager;

use base 'Pixie::Object';
use strict;
use Scalar::Util qw/weaken/;

our $VERSION = '2.02';

sub set_pixie {
  my $self = shift;;
  $self->{pixie} = shift;
  weaken $self->{pixie};
  return $self;
}

sub rebless {
  my $self = shift;
  my($obj) = @_;

  bless($obj, $self->shadowclass_for($obj));
  return $obj;
}

sub shadowclass_for {
  my $self = shift;
  my($obj) = @_;

  my $class = ref $obj;
  return $class if ($class->isa('Pixie::Object') ||
		    $class->isa('Pixie::ShadowClass'));

  return $self->{_classmap}{$class} if exists $self->{_classmap}{$class};

  my $shadow_classname =
    'Pix' . (0+$self) . '::' . $class;

  my $code_string = qq{package $shadow_classname;
            use vars qw(\%dont_do_real_dest);
		    use base qw(Pixie::ShadowClass $class);
		    sub real_class { '$class' }
		    sub _PIXIE_pixie {
		      \${$ {shadow_classname}\::class_manager}->{pixie}
		    }
		  };

  eval $code_string;
  die $@ if $@;

  no strict 'refs';
  ${$shadow_classname . '::class_manager'} = $self;
  $self->{_classmap}{$class} = $shadow_classname;
  return $shadow_classname;
}

package Pixie::ShadowClass;

use base 'Pixie::ManagedObject';

sub DESTROY {
  my $self = shift;
  ($self->_PIXIE_pixie || 'Pixie')->forget_about($self);
  return if $self->_PIXIE_dont_do_real_DEST;
  my $next = $self->real_class->can('DESTROY');
  $self->$next() if $next;
}

my %dont_do_real_dest;

sub _PIXIE_dont_do_real_DEST {
  my $self = shift;
  my $shadow_classname = ref $self;
  bless $self, 'Class::Whitehole';
  my $retval;
  if (@_) {
    $dont_do_real_dest{+$self} = shift;
  }
  else {
    $retval = delete $dont_do_real_dest{+$self};
  }
  bless $self, $shadow_classname;
  return $retval;
}


1;
