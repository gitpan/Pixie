#!perl -w

##
## Pixie::Info tests
##

use lib 't/lib';
use blib;
use strict;

use Test::More tests => 26;
use Scalar::Util qw/weaken isweak/;

BEGIN { use_ok 'Pixie::Info', qw/px_get_info px_set_info/ }

my($count1, $count2);

do {
    $count1 = $count2 = 0;
    my $info = bless [], 'ThisTest::Dummy1';
    my $test1 = {};
    my $test2 = {};
    my $test3 = $test1;
    is px_set_info($test1, $info), $test1;

    my $test4 = $test1;
    is px_get_info($test1), $info, 't1';
    is px_get_info($test2), undef, 't2';
    is px_get_info($test3), $info, 't3';
    is px_get_info($test3), $info, 't3x';
    is px_get_info($test4), $info, 't4';
    is px_get_info($test1), $info, 't1x';

    is $count1, 0;
};

is $count1, 1, 'info object is destroyed';


do {
    $count1 = $count2 = 0;
    my $info1 = bless [], 'ThisTest::Dummy1';
    my $info2 = bless {}, 'ThisTest::Dummy2';
    my $test1 = {};
    px_set_info($test1, $info1);
    is px_get_info($test1), $info1, 't1';

    px_set_info($test1, $info2);
    is px_get_info($test1), $info2, 't1';

    is $count1, 0;
    is $count2, 0;
};

is $count1, 1, 'info object is destroyed';
is $count2, 1, 'info object is destroyed';


do {
    $count1 = $count2 = 0;
    my $test1 = {};
    px_set_info($test1, \ "1" );
};
do {
    $count1 = $count2 = 0;
    my $test1 = {};
    px_set_info($test1, bless [], 'ThisTest::Dummy1');
    is !px_get_info($test1), '', 't1';
    is $count1, 0;

    px_set_info($test1, bless [], 'ThisTest::Dummy2');
#    is px_get_info($test1), $info2, 't1';

    is $count1, 1, 'info object is destroyed';
    is $count2, 0;
};

is $count2, 1, 'info object is destroyed';


do {
    $count1 = $count2 = 0;
    my $info = 1;
    my $test1 = {};
    px_set_info($test1, $info);
    is px_get_info($test1), $info, 't1';

    px_set_info($test1, 2);
    is px_get_info($test1), 2, 't1';

    is $count1, 0;
    is $count2, 0;
};


my $t1 = {};
do {
    my $t2 ={};
    px_set_info($t2,55);
    px_set_info($t1,$t2);
};
my $t2 = px_get_info($t1);
is px_get_info($t2), 55;


package ThisTest::Dummy1;

sub DESTROY {
    $count1++;
}

1;

package ThisTest::Dummy2;

sub DESTROY {
    $count2++;
}
