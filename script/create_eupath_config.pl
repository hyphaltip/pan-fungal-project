#!/usr/bin/perl -w

use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../lib/perl";
use FungiDB::Repository;
use FungiDB::GUS::Templates;

my $repo = FungiDB::Repository->new();

my $entries = $repo->crawl;

foreach (@$entries) {
    my ($species,$strain,$version) = @$_;
    my $template = FungiDB::GUS::Templates->new();
    $template->generate_isf_datasource($species,$strain);
    
}
