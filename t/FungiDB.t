#t/FungiDB.t

use strict;
use warnings;

use Test::More qw/no_plan/;

use FungiDB;

BEGIN {
    use_ok('FungiDB');
}

ok( my $pf = FungiDB->new(),
    'instantiated FungiDB class ok'
    );

my $sources = $pf->sources;
ok($sources,'fetching sources: ' . join('; ',@$sources));

my $organisms = $pf->organisms;
ok($organisms,'fetching organisms: ' . join('; ',@$organisms));
