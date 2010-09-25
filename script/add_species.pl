#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use File::Spec;

my $args = shift;

$args or die "Usage: $0 [genus_species] -- create stub entries for a new species\n\n";



my ($genus,$species) = split("_",$args);
create_organism_module($genus,$species);


# Create a new Organism::*.pm
sub create_organism_module {
    my ($g,$s) = @_;
    my $package = lc($g) . '_' . $s;
    open my $module,'>',"$Bin/../lib/FungiDB/Organism/$package.pm" or die "Couldn't open the module for writing': $!";

    print $module <<END;
package FungiDB::Organism::$package;

use Moose;

with 'FungiDB::Roles::Organism';
extends 'FungiDB';

no Moose;
1;

END

    close $module;


}
