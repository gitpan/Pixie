##
## Pixie::FinalMethods test final methods placed in PIXIE
##

use lib 't/lib';
use blib;
use strict;
use warnings;

use Test::More qw( no_plan );
use Test::Exception;
use Test::MockObject;

use MockPixie qw( $pixie );

BEGIN { use_ok( 'Pixie::FinalMethods' ); }

ok( UNIVERSAL::can( 'Pixie::ObjectInfo', 'new' ), 'loads Pixie::ObjectInfo' );

my $sv      = 'scalar';
my $sv_obj  = bless \$sv, 'MyScalarObject';
my $hv_obj  = bless {a => 'hash'}, 'MyHashObject';
my $av_obj  = bless [qw( a b c )], 'MyArrayObject';
my $sv_info = Pixie::ObjectInfo->new;

## address
ok( index(sprintf("%x", $hv_obj->PIXIE::address), "$hv_obj"), ' returns memory addr' );

## set/get info
is( $sv_obj->PIXIE::set_info( $sv_info ), $sv_obj,     'set_info' );
is( $sv_obj->PIXIE::get_info, $sv_info,                'get_info' );
isa_ok( $hv_obj->PIXIE::get_info, 'Pixie::ObjectInfo', 'get_info, lazy init' );

## managing_pixie
is( $sv_obj->PIXIE::managing_pixie, undef,  'managing_pixie (created by new)' );
is( $hv_obj->PIXIE::managing_pixie, $pixie, 'managing_pixie (created lazily)' );

## set/get exceptions
my $info2 = Pixie::ObjectInfo->new;
dies_ok { $sv_obj->PIXIE::set_info( 'bad' ) }   'set_info, info not ObjectInfo';
dies_ok { $sv_info->PIXIE::set_info( $info2 ) } 'set_info, cant set info on ObjectInfo';
dies_ok { $sv_info->PIXIE::get_info }           'get_info, cant get info on ObjectInfo';

## set/get oid
is( $sv_obj->PIXIE::set_oid( 'test oid' ), $sv_obj, 'set_oid' );
is( $sv_obj->PIXIE::oid, 'test oid',                'oid' );

## undef info
$sv_obj->PIXIE::get_info->set__oid( 'test' );
$sv_obj->PIXIE::set_info( undef );
my $undef_info = $sv_obj->PIXIE::get_info;
isnt( $undef_info->_oid, 'test', 'set_info(undef)' );

