package FungiDB::Source::broad;

use Moose;
use WWW::Mechanize;

=pod

The Broad has a single page per organism (or groups of related organisms)
with a mostly standardized naming convention.

=cut

with 'FungiDB::Roles::Source';
extends 'FungiDB';



has 'filenames' => (is => 'ro',
		    isa => 'HashRef',
		    );

has 'preferred_compression' => (is => 'ro');
				
			      
sub _build_preferred_compression {
    my $self = shift;
    my $name = $self->symbolic_name;
    my $compression = $self->config->{source}->{$name}->{preferred_compression};
    return $compression;
}

# Filenames stored in config.
# Could be used system-wide perhaps.
sub _build_filenames {
    my $self = shift;
    my $name = $self->symbolic_name;
    my $filenames = $self->config->{source}->{$name}->{filenames};
    return $filenames;
}




# Provided with a species, download all available files.
# Maybe not what you want to do.
sub slurp {
    my $self     = shift;
    my $organism = shift;

    my $url = $organism->index_url;

    # Lots of variability in species, but not the file roots. Meh.
    # TO-DO. Needs to be standardized.
    my $file_template = $organism->file_template;

    # Get the repository destination
    my $repository = $self->repository;
   
    my $mech = WWW::Mechanize->new(autocheck => 1);
    $mech->get($url);
    
    my $compression = $self->preferred_compression;
    
    my @links = $mech->links();    
    foreach my $link (@links) {
	my ($filename,$title) = $self->_check_title_tag($link);

	# The current link MAY be a file that we want.	
	if ($filename) {
	    $self->log->debug("We scraped by a file of interest: $filename, title=$title");

	    my ($full_filename,$strain,$assembly) = $self->_parse_title($organism,$title,$filename);
	    $self->log->debug("Extracted strain from file: $strain");
	    next unless ($strain); # MINIMALLY, assume that we have matched a strain.
	    
#	    next unless $extracted_organism =~ /$species/i;
#	    $self->log->debug("Extracted species matches requested species; we'll download '$full_filename'");
	    
	    # Fetch the file. I need the:
	    #    full filename - for post processing
	    #    file URL - for fetching
	    #    organism - for post-processing files
	    #    extracted_organism - for where to mirror the file

	    # By default, we mirror into species/raw/extracted_organism name.
	    # This is maybe cleaner as species/STRAIN/raw...
	    
	    my $path = join('/',
			    $organism->symbolic_name
			    ,$strain || 'unknown-strain',
			    ,$assembly || 'unknown-assembly',
				 ,'raw');	    
	    $repository->mirror_file_by_http($mech,
					     $path,
					     $full_filename,
					     $self->base_url . '/' . $link->url,
					     );
	}
    }
}


# Broad-specific helpers.
sub _check_title_tag {
    my ($self,$link) = @_;
    
    my $compression = $self->preferred_compression;
    my $attrs = $link->attrs();
    my $filenames = $self->filenames;
    foreach my $filename (keys %$filenames) {
	if ($attrs->{title} && $attrs->{title} =~ /_$filename\.$compression/) {
	    return ($filename,$attrs->{title});
	}
    }
}


sub _parse_title {
    my ($self,$organism,$title,$filename) = @_;

    # Is this file from one of the strains we are interested in?
        
    # Lots of variablity, unfortunately:
    #   Download fusarium_oxysporum_f._sp._lycopersici_2_genome_summary_per_gene.txt.zip
    #	Download fusarium_verticillioides_3_genome_summary_per_gene.txt.zip
    #	Download cryptococcus_neoformans_grubii_h99_2_genome_summary_per_gene.txt.zip
    # The solution for now is to hard-code strains we are interested in config.
    
    my $strains = $organism->strains;    
    my $name    = $organism->symbolic_name;
    foreach my $strain (@$strains) {

	# Some orgs not identified by strain; just use the name of the organism
	my $full_name = $strain eq 'unknown' ? $name : $name . '_' . $strain;
	if ($title =~ /$full_name/) {
	    
	    my ($full_filename) = $title =~ /Download\s(.*)/;
	    
	    # currrently does NOT work for extracting assembly
	    my ($assembly) = $title =~ /Download\s$full_name\_(.*)_$filename/;
	    $self->log->debug("Found a filename from a species & strain of interest: $full_filename, with POSSIBLE assembly of $assembly");

	    return ($full_filename,$strain,$assembly);	    
	}
    }
}


=pod

Fact-finding:  

A page that has a species group:

Top link: http://www.broadinstitute.org/annotation/genome/fusarium_group/MultiDownloads.html
Filenames : drawn from the title elements shown below with basic structure of
   <a title="Download {genome||mito}_{filename}" href=...

File roots:
   genome = {genus}_{species}_{assembly}
   mito   = {genus}_{species}_mitochondrial_{assembly}

If {assembly} is absent, refers to a .tar.gz containing all old assemblies.
    
    Available files
    supercontigs.fasta : supercontigs.fasta.gz
    contigs.fasta      : contigs.fasta.gz
    contigs.agp        : contigs.agp.gz
    chromosomal.agp    : chromosomal.agp.gz
    all_files          : data.tar.gz
    
    genes.fasta        : genes.fasta.gz
    transcripts.fasta  : transcripts.fasta.gz
    transcripts.gtf    : transcripts.gtf.gz
    proteins.fasta     : proteins.fasta.gz
    proteins_stops.fasta : protein_stops.fasta.gz
    pfam_to_genes.txt  : pfam_to_genes.txt
    genes_upstream_1000.fasta : genes_upstream_1000.fasta.gz
    genes_upstream_utr_1000.fasta : genes_upstream_utr_1000.fasta.gz
    genes_downstream_1000.fasta : genes_downstream_1000.fasta.gz
    genes_downstream_utr_1000.fasta : genes_downstream_utr_1000.fasta.gz
    genome_summary.txt  : genome_summary.txt.gz
    genome_summary_per_gene.txt : genome_summary_per_gene.txt.gz
    all_data      : (as above)
    
=cut




1;
