#t/FungiDB.t

use strict;
use warnings;

use Test::More qw/no_plan/;

use FungiDB::Sources::SGD;

BEGIN {
    use_ok('FungiDB::Source');
}

ok( my $pf = FungiDB::Sources::SGD->new(),
    'instantiated FungiDB::Source class ok'
    );

my $sources = $pf->sources;
ok($sources,'fetching sources: ' . join('; ',@$sources));

my $organisms = $pf->organisms;
ok($organisms,'fetching organisms: ' . join('; ',@$organisms));
