##
## A basic fake Pixie which behaves like Pixie
##

package MockPixie;

use Test::MockObject;

use base qw( Exporter );
our @EXPORT_OK = qw( $pixie $lockstrat );

our $pixie = Test::MockObject->new
  ->set_always( '_oid' => 'pixie oid' )
  ->set_always( 'cache_delete' => 1 );

our $lockstrat = Test::MockObject->new
  ->set_always( 'on_DESTROY' => 1 );

sub Pixie::get_the_current_pixie { $pixie }
sub Pixie::LockStrat::Null::new  { $lockstrat }
