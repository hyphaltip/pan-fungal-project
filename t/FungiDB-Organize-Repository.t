#t/FungiDB::Organize::Repository.t

use strict;
use warnings;

use Test::More qw/no_plan/;

use FungiDB::Organize::Repository;

BEGIN {
    use_ok('FungiDB::Organize::Repository');
}

ok( my $repository = FungiDB::Organize::Repository->new(),
	    'instantiated Repository class'
    );


my $root = $repository->root;
ok ($root,"fetched the root location of repository: $root");


$repository->establish(1);