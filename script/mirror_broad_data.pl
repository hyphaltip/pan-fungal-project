#!/usr/bin/perl

use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use FungiDB;

my $fungidb = FungiDB->new();

# Fetch a Source::broad object from our factory.
my $broad = $fungidb->source('broad');

# Organism by organism... boring...
if (0) {
# Get a list of all organisms of interest at the Broad.
    my $organisms = $broad->organisms;
    
    foreach my $organism (@$organisms) {
	$fungidb->log->info("Slurping down " . $organism->symbolic_name);
	$broad->slurp($organism);
    }
}

# All at once. Yay!
my $urls = $broad->download_index_page_urls();
$broad->slurp_all($urls);


