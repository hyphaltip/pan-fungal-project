#t/FungiDB::Organisms.t

use strict;
use warnings;

use Test::More qw/no_plan/;

use FungiDB;

BEGIN {
    use_ok('FungiDB');
}

ok( my $fungidb = FungiDB->new(),
	    'instantiated FungiDB class ok'
    );



my $organisms = $fungidb->organisms();
ok (@$organisms > 0,"Fetched some organisms");
foreach (@$organisms) {
    ok ($_->genus, join(" ",$_->genus,$_->species));

    # Fetch the source of this organism.
    my $source = $_->source;
    ok($_->title,"Organism hosted by " . $_->title);	
}