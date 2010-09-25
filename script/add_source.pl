#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use File::Spec;

my $args = shift;

$args or die "Usage: $0 [source_symbolic_name] -- create stub entries for a new source\n\n";


create_source_module($args);


# Create a new Organism::*.pm
sub create_source_module {
    my ($args) = @_;
    my $package = "$args";
    open my $module,'>',"$Bin/../lib/FungiDB/Source/$package.pm" or die "Couldn't open the module for writing': $!";

    print $module <<END;
package FungiDB::Source::$package;

use Moose;

with 'FungiDB::Roles::Source';
extends 'FungiDB';

1;
END

 close $module;

}
