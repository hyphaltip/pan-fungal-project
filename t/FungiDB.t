#t/FungiDB.t

use strict;
use warnings;

use Test::More qw/no_plan/;
use FindBin qw/$Bin/;
use lib "$Bin/../lib/perl";
use FungiDB;

BEGIN {
    use_ok('FungiDB');
}

ok( my $fungidb = FungiDB->new(),
    'instantiated FungiDB class'
    );

# Fetch all available data sources
my $sources = $fungidb->sources;
ok($sources,'available sources: ' . join('; ',map { $_->title . '(' . $_->symbolic_name . ')' } @$sources));

# Fetch a list of all organisms
my $all_organisms = $fungidb->organisms;
ok($all_organisms,'available organisms: ' . join('; ',map { $_->genus . " " . $_->species } @$all_organisms));


######################################
#
# Fetch a single resource and all the
# organisms it is responsible for.
#
######################################
my $source = $fungidb->source('sgd');
ok ($source->isa("FungiDB::Source::sgd"),
	"fetching a single source by its symbolic name: sgd");

# Get a list of all organisms provided by this source.
my $organisms = $source->organisms;
ok($organisms,$source->title . " responsible for: " . join('; ',map { $_->genus . ' ' . $_->species } @$organisms));






######################################
#
# Fetch a single organism and grab some
# information about it.
#
######################################
my $organism = $fungidb->organism('saccharomyces_cerevisiae');
ok ($organism->genus eq 'Saccharomyces','fetched a single organism directly: ' . $organism->symbolic_name);
ok($organism->source eq 'sgd', 'interrogated the organism configuration for its source: ' .  $organism->source);