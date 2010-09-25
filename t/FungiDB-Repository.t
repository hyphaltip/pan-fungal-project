#t/FungiDB::Repository.t

use strict;
use warnings;
use FindBin qw/$Bin/;

use Test::More qw/no_plan/;

use FungiDB::Repository;

BEGIN {
    use_ok('FungiDB::Repository');
}

ok( my $repository = FungiDB::Repository->new(debug => 1),
	    'instantiated Repository class'
    );


$repository->establish("$Bin/../test-data-repository");

my $root = $repository->root;
ok ($root,"fetched the root location of repository: $root");

