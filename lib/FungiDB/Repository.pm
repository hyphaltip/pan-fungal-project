package FungiDB::Repository;

use Moose;
use File::Path;
extends 'FungiDB';

has 'root' => ( is => 'ro',
		lazy_build => 1 );

has 'species_directories' => ( is => 'ro',
			      lazy_build => 1 );

has 'readme_filename' => ( is => 'ro',
			   lazy_build => 1 );

has 'version_filename' => ( is => 'ro',
			    lazy_build => 1 );



# Kind of anti-moose to write these accessors. Oh well, it's expedient for now.
sub _build_root {
    my $self = shift;
    return $self->config->{repository}->{root};
}

sub _build_readme_filename {
    my $self = shift;
    return $self->config->{repository}->{readme_filename};
}

sub _build_versioN_filename {
    my $self = shift;
    return $self->config->{repository}->{version_filename};
}

sub _build_species_directories {
    my $self = shift;
    my @dirs = @{$self->config->{repository}->{species_directory}};
    return \@dirs;
}


# Establish a new repository.
# The basic structure looks like:
# by_organism/ -- the primary repository
# by_source/  -- with symlinks to by_organism
# by_taxonomy -- with symlinks to by_organism

# by_organism looks like this:
# saccharomyces_cerevisiae/
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/README
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/VERSION
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/gff
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/sequence
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/original
# saccharomyces_cerevisiae/current -> {STRAIN}/{VERSION}

sub establish {
    my $self = shift;
    my $test = 1;
    my $root = $self->root;
    
    # Create the root directory if it doesn't already exist
    unless ( -e $root) {
	unless ($test) {
	    mkpath $root or die "oh no, we could't create the repository root: $!";
	    mkpath ("$root/by_species",
		    "$root/by_source",
		    "$root/by_taxonomy",
		    { verbose => 1,
		      mode    => 2775,
		  }) or die "oh no, we could't create the repository root: $!";
	}
    }
    
    $self->by_species($root,$test);
    # $self->by_source();     # Not ready yet.
    # $self->by_taxonomy();   # Not ready yet.
}



sub by_species {
    my $self = shift;
    my $root = shift;
    my $test = shift;
        
    # Get a list of all organisms
    my $organisms = $self->organisms;
    foreach my $organism (@$organisms) {
	my $name = lc($organism->index_name);
	
	# Escape possibly dangerous characters
	$name =~ s/[\'\*\\\/]//g;
	
	my $date = `date +%Y-%m-%d`;
	chomp $date;
#	my $version = $organism->version() || "version_unknown-$date";
	
	my $version = "unknown_version--$date";

#	mkpath acts like mkdir -p
#	if ($test) { 
#	    print STDERR "$root/by_species/$name\n";
#	    print STDERR "$root/by_species/$name/$version\n",
#	} else {
#	    mkpath("$root/by_species/$taxonomy",
#		   { verbose => 1,
#		     mode    => 2775,
#		 });
#	    
#	    mkpath("$root/by_species/$taxonomy/$version",
#		   { verbose => 1,
#		     mode    => 2775,
#		 });
	
	
	my $strains = $organism->strains;
	foreach my $strain (@$strains) {
	    my $species_directories = $self->species_directories();
	    foreach my $dir (@$species_directories) {
		
		if ($test) { 
		    print STDERR "$root/by_species/$name/$strain/$version/$dir\n";
		} else {
		    mkpath("$root/by_species/$name/$strain/$version/$dir",
			   { verbose => 1,
			     mode    => 2775,
			 });		   
		}
	    }
	}
	
	# Symlink to the current version. This really belongs in
	# mirroring and updating code.    

	# Create README stubs.
	# Create VERSION stubs.


	
    }
}



no Moose;

1;
