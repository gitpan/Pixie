##
## Pixie::Complicity test default methods placed in UNIVERSAL
##

use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::MockObject;

BEGIN { use_ok( 'Pixie::Complicity' ); }

my $sv     = 'scalar';
my $sv_obj = bless \$sv, 'MyScalarObject';
my $hv_obj = bless {a => 'hash'},   'MyHashObject';
my $av_obj = bless [qw( a b c )],   'MyArrayObject';

if (can_ok( 'UNIVERSAL', 'px_is_storable' )) {
    ok( !$sv_obj->px_is_storable, 'sv objs not storable' );
    ok(  $hv_obj->px_is_storable, 'hv objs storable' );
    ok(  $av_obj->px_is_storable, 'av objs storable' );
}

if (can_ok( 'UNIVERSAL', 'px_class' )) {
    is( $sv_obj->px_class, 'MyScalarObject', ' returns class' );
}

if (can_ok( 'UNIVERSAL', 'px_oid' )) {
    sub PIXIE::oid { ok( $_[0], ' calls PIXIE::oid' ); return 'oid'; }
    is( $sv_obj->px_oid, 'oid', ' returns oid' );
}

if (can_ok( 'UNIVERSAL', 'px_freeze' )) {
    is( $hv_obj->px_freeze, $hv_obj, ' returns itself' );
}

if (can_ok( 'UNIVERSAL', 'px_thaw' )) {
    is( $hv_obj->px_thaw, $hv_obj, ' returns itself' );
}

if (can_ok( 'UNIVERSAL', 'px_is_immediate' )) {
    ok( !$hv_obj->px_is_immediate, ' not immediate by default' );
}

if (can_ok( 'UNIVERSAL', 'px_in_rootset' )) {
    ok( $hv_obj->px_in_rootset, ' in rootset by default' );
}

if (can_ok( 'UNIVERSAL', 'px_as_rawstruct' )) {
    my $sv_obj2 = $sv_obj->px_as_rawstruct;
    isnt( $sv_obj2, $sv_obj,      ' sv is a copy' );
    is_deeply( $sv_obj2, $sv_obj, ' sv copy is same as orig' );
    my $hv_obj2 = $hv_obj->px_as_rawstruct;
    isnt( $hv_obj2, $hv_obj,      ' hv is a copy' );
    is_deeply( $hv_obj2, $hv_obj, ' hv copy is same as orig' );
    my $av_obj2 = $av_obj->px_as_rawstruct;
    isnt( $av_obj2, $av_obj,      ' av is a copy' );
    is_deeply( $av_obj2, $av_obj, ' av copy is same as orig' );
}

if (can_ok( 'UNIVERSAL', 'px_empty_new' )) {
    sub MyScalarObject::new {
	my $thing = shift;
	ok( 1, ' calls new' );
      TODO: {
	    local $TODO = 'calls new';
	    ok( !ref( $thing ), ' calls new on the class (not obj)' );
	}
	$thing;
    }
    ok( $sv_obj->px_empty_new, ' returns ok' );
}

my $pixie = Test::MockObject->new
  ->set_always( 'make_new_object',   'new_obj' )
  ->set_always( 'extraction_freeze', 'efreeze' )
  ->set_always( 'extraction_freeze', 'efreeze' )
  ->set_always( 'extraction_thaw',   'ethaw'   )
  ->set_always( 'insertion_freeze',  'ifreeze' )
  ->set_always( 'insertion_thaw',    'ithaw'   );
sub Pixie::get_the_current_pixie { return $pixie }

if (can_ok( 'UNIVERSAL', 'px_do_final_restoration' )) {
    is( $sv_obj->px_do_final_restoration, 'new_obj', ' sends msg to Pixie' );
}

# 'Internal' methods

if (can_ok( 'UNIVERSAL', '_px_extraction_freeze' )) {
    is( $sv_obj->_px_extraction_freeze, 'efreeze', ' sends msg to Pixie' );
}

if (can_ok( 'UNIVERSAL', '_px_extraction_thaw' )) {
    is( $sv_obj->_px_extraction_thaw, 'ethaw', ' sends msg to Pixie' );
}

if (can_ok( 'UNIVERSAL', '_px_insertion_freeze' )) {
    is( $sv_obj->_px_insertion_freeze, 'ifreeze', ' sends msg to Pixie' );
}

if (can_ok( 'UNIVERSAL', '_px_insertion_thaw' )) {
    is( $sv_obj->_px_insertion_thaw, 'ithaw', ' sends msg to Pixie' );
}


