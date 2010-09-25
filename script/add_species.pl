#!/usr/bin/perl -w

use FindBin qw/$Bin/;
use File::Spec;
use Getopt::Long;
use strict;

my ($genus,$species,$source,$url,$clade,$description);

my %args = ();
GetOptions( \%args,
	    'genus=s',
	    'species=s',
	    'source=s',
	    'url=s',
	    'clade=s',
	    'strain=s',
	    'description=s',
	    );

if (keys %args < 7 || exists $args{help} ) { 
    die <<END

Usage: $0

 Options
 --genus       Genus 
 --species     species 
 --source      broad, jgi, genbank
 --url         home URL for the species
 --clade       Ascomycota, eg 
 --description model system|human pathogen|plant_pathogen]
 --strain      reference strain, if known

END
}


create_organism_module($args{genus},$args{species});
append_to_conf(\%args);

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


sub append_to_conf {
    my ($genus,$species,$source,$url,$clade,$description,$strain) = ($args{genus},$args{species},$args{source},$args{url},$args{clade},$args{description},$args{strain});
    open my $conf,'>>',"$Bin/../conf/fungidb.conf" or die "Couldn't open the conf for writing': $!";

    $genus = ucfirst($genus);  # ensure proper nomenclature
    my $name = lcfirst($genus) . '_'  . $species;

    print $conf <<END;

<organism $name>

    # The symbolic name of the source of this organism
    source     = $source
   
    # Broad organisms have an index page listing downloads.
    index_url = $url

    # (possibly) Broad-specific: filename root format.
    # here %s is the strain name, lowercase
    file_template =
    
    # Description: model system | human pathogen | plant pathogen
    description = $description

    clade   = $clade
    kingdom =
    phylum  =
    class   = 
    order   =
    family  =
    genus   = $genus
    species = $species

    # One or many strains
    <strain $strain>

         # Location and version of gff (if available).
         <gff>
              url        = 
              version    = 

     	      # Optionally provide the name of a script for post-processing
               process_bin =
          </gff>

          # Location of sequences in fasta
          <sequence>
               <genomic>
               </genomic>
               <spliced>
               </spliced>
               <unspliced>
               </unspliced>
               <translation>
               </translation>  
           </sequence>
       </strain>
</organism>
END

    close $conf;
}
