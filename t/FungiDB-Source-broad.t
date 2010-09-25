#t/FungiDB-Source-broad.t

use strict;
use warnings;

use Test::More qw/no_plan/;

use FungiDB;

BEGIN {
    use_ok('FungiDB');
}

# Try using the module directly, too.
BEGIN {
    use_ok('FungiDB::Source::broad');
}


ok( my $fungidb = FungiDB->new(),
    'instantiated FungiDB class'
    );


# Fetch a broad object.
my $source = $fungidb->source('broad');
ok ($source->isa("FungiDB::Source::broad"),
	"fetching a single source by its symbolic name: broad");

# Get a list of all organisms provided by this source.
my $organisms = $source->organisms;
ok($organisms,$source->title . " responsible for: " . join('; ',map { $_->genus . ' ' . $_->species } @$organisms));


# Update the mirror for all organisms from this source
foreach my $organism (@$organisms) {
     $source->slurp($organism);
}