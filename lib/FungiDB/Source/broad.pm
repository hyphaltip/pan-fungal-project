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



# Get a list of all the top level links for Broad fungi
# This page contains a list of all fungal projects
# http://www.broadinstitute.org/science/projects/fungal-genome-initiative/current-fgi-sequence-projects

# Each is a link to a page containing a single genome ...
#  /annotation/genome/multicellularity_project/MultiHome.html             # index page 
#  /annotation/genome/batrachochytrium_dendrobatidis/MultiDownloads.html  # Downloads

# ... or multiple genomes
# /annotation/genome/aspergillus_group/                      # index page
# /annotation/genome/aspergillus_group/MultiDownloads.html   # Downloads link

# OR Downloads.html

sub download_index_page_urls {
    my $self  = shift;
    my $name  = $self->symbolic_name;
    my $index = $self->config->{source}->{$name}->{species_index_url};
    my $mech = WWW::Mechanize->new(autocheck => 1);

    $mech->get($index);

    my @links = $mech->links();    
    my %links;
    foreach my $link (@links) {
	my $url = $link->url;
	next unless $url =~ m{/annotation/[fungi|genome]};

	# 2010.09.27: HACK! Yeast Comparative Genomics download page
	# has different URL and the page structure is different.

	# Some of the URLs are broke. Lame.
	next if ($url =~ /comp_yeasts/);
	next if ($url =~ /chaetomium_globosum/);
	next if ($url =~ /lacazia/);
	$url = ($url =~ /^h/) ? $url : $self->base_url . $url;
	
	# Guess the download page and build the url.
	# This doesn't always work since some pages are actually Home.html
	if (1) {
	    
	    # Append the home link so I can avoid redirects if we have a trailing slash
	    $url = "$url/" if $url =~ /\w$/;       
	    $url =~ s/MultiHome\.html//g;
	    $url =~ s/Home\.html//g;
	    
	    # Append the downloads link
	    $url .= 'MultiDownloads.html';
	    $links{$url} = $link->text;   # Maybe species

	} 
	
	# AND try to do it systematically.
	my $mech2 = WWW::Mechanize->new();
#	    $mech2->redirect_ok();
	
	$mech2->get($url) or die;
	my @inner_links = $mech2->links();
	foreach (@inner_links) {
	    
	    next unless $_->text && $_->text eq 'Download';
#	    $self->log->debug($_ . $_->text . ': ' . $_->url) if $self->debug;

	    my $download_page = $_->url;
	    
	    # fix broken relative links
	    $download_page = ($download_page !~ /^\// && $download_page !~ /^http/) ? "/$download_page" : $download_page; 

	    # Append the base for relative links	    
	    $download_page = ($download_page =~ /^h/) ? $download_page 
		: $self->base_url . $download_page;
	    
	    # Replace Downloads.html with MultiDownloads.html
	    $download_page =~ s/Downloads\.html/MultiDownloads\.html/;

	    # Get rid of session IDs; the url is 0th element
	    my @url_pieces = split(';',$download_page);

	    # uniqiufy by URL - lots of duplicates on the page
	    $links{$url_pieces[0]} = $_->text;   # Maybe species
	    $self->log->debug($url_pieces[0]);	
	}
    }
    return \%links;
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
#    $mech->redirect_ok();

    $mech->get($url);
    
    my $compression = $self->preferred_compression;
    
    my @links = $mech->links();    
    foreach my $link (@links) {
	my ($filename,$title) = $self->_check_title_tag($link);

	# The current link MAY be a file that we want.	
	if ($filename) {
	    $self->log->debug("We scraped by a file of interest: $filename, title=$title") if $self->debug;

	    my ($full_filename,$strain,$assembly) = $self->_parse_title_by_organism($organism,$title,$filename);
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
#	$self->log->debug($filename . ' ' . $attrs->{title});
	if ($attrs->{title} && $attrs->{title} =~ /.*_$filename\.$compression/) {
	    return ($filename,$attrs->{title});
	}
    }
}


sub _parse_title_by_organism {
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


# Slurp ALL species from Broad download pages.
sub slurp_all {
    my $self     = shift;
    my $urls     = shift;   # A list of download page URLs

    # Get the repository destination
    my $repository = $self->repository; 
    
    my $mech = WWW::Mechanize->new();
    
    foreach my $url (keys %$urls) {
	my $full_url = ($url =~ /^h/) ? $url : $self->base_url . $url;
	if ($mech->get($full_url)) {
	
	    $self->log->debug("Succesfully fetched the download page at $url");
	    
	    my $compression = $self->preferred_compression;
	    
	    my @links = $mech->links();    
	    foreach my $link (@links) {
		my ($filename,$title) = $self->_check_title_tag($link);
		
		# The current link MAY be a file that we want.	
		if ($filename) {
		    $self->log->debug("We scraped by a file of interest: $filename, title=$title") if $self->debug;
		    
		    my ($full_filename,$genus_species,$strain,$assembly) = $self->_parse_title($title,$filename);
		    next unless $full_filename;
		    
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
				    $genus_species,
				    ,$strain,
				    ,$assembly,
				    ,'raw');	    
	
		    # Save the species, strain, and assembly here. Redundant, but it works.
		    $self->dump_version_history({ species => $genus_species,
						    strain  => $strain,
						    version => $assembly,
						    path    => $path,
						    source  => $self->symbolic_name,
						});
	    
		    $self->log->debug("fetching $full_filename: $genus_species; strain: $strain; assembly $assembly\n") if $self->debug;
		    
		    $repository->mirror_file_by_http($mech,
						     $path,
						     $full_filename,
						     $self->base_url . '/' . $link->url,
						     );
		}
	    }
	}
    }
}



sub _parse_title {
    my ($self,$title,$filename) = @_;

    # Is this file from one of the strains we are interested in?
        
    # Lots of variablity, unfortunately:
    #   Download fusarium_oxysporum_f._sp._lycopersici_2_genome_summary_per_gene.txt.zip
    #	Download fusarium_verticillioides_3_genome_summary_per_gene.txt.zip
    #	Download cryptococcus_neoformans_grubii_h99_2_genome_summary_per_gene.txt.zip    
    my ($full_filename)  = $title =~ /Download\s(.*)/;
    
    # Clean up the title a bit to make things easier
    my $comp = $self->preferred_compression;
    $title =~ s/Download\s//g;
    $title =~ s/$filename\.$comp//g;
    
    my ($genus,$species,@fields) = split(/_/,$title);
    my $assembly = pop @fields;
    my $strain   = @fields ? join('_',@fields) : 'unknown-strain';
    $assembly ||= 'unknown-assembly';

    my $full_name = $genus . '_' . $species;

    $self->log->debug("Found $full_filename from a species & strain of interest: $genus $species, strain $strain, with POSSIBLE assembly of $assembly")
	if $self->debug;
    
    return ($full_filename,$full_name,$strain,$assembly);
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
