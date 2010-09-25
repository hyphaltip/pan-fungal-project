package FungiDB::Repository;

use Moose;
use File::Path;
extends 'FungiDB';

has 'root' => ( is => 'rw',
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
# saccharomyces_cerevisiae/raw  - original datafiles
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/README
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/VERSION
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/gff
# saccharomyces_cerevisiae/{STRAIN}/{VERSION}/sequence
# saccharomyces_cerevisiae/current -> {STRAIN}/{VERSION}

sub establish {
    my $self = shift;
    my $test_directory = shift;   # Over-rides root
    $self->root($test_directory) if $test_directory;

    my $root = $self->root;
    
    # Create the root directory if it doesn't already exist
    unless ( -e $root) {
	    mkpath $root or die "oh no, we could't create the repository root: $!";
	    mkpath ("$root/by_species",
		    "$root/by_source",
		    "$root/by_taxonomy",
		    { verbose => 1,
		      mode    => 0775,
		  }) or die "oh no, we could't create the repository root: $!";
    }
    
    $self->by_species();
    # $self->by_source();     # Not ready yet.
    # $self->by_taxonomy();   # Not ready yet.
}

sub by_species {
    my $self = shift;
    my $root = $self->root;

    # Get a list of all organisms
    my $organisms = $self->organisms;
    foreach my $organism (@$organisms) {
	my $species = lc($organism->symbolic_name);
	
#	# Mirror directory. Should be configurable.
	# Nope. now mirroring to species/strain/version/raw
#	mkpath("$root/by_species/$species/raw",
#	       { verbose => $self->debug,
#		 mode    => 0775,
#	     });

	# Escape possibly dangerous characters
	$species =~ s/[\'\*\\\/]//g;
	
	my $date = `date +%Y-%m-%d`;
	chomp $date;
#	my $version = $organism->version() || "version_unknown-$date";
	
	my $version = "unknown_version-$date";

#	mkpath acts like mkdir -p
#	    mkpath("$root/by_species/$taxonomy",
#		   { verbose => $self->debug,
#		     mode    => 0775,
#		 });
#	    
#	    mkpath("$root/by_species/$taxonomy/$version",
#		   { verbose => $self->debug,
#		     mode    => 0775,
#		 });
	
	my $strains = $organism->strains;
	foreach my $strain (@$strains) {
	    my $species_directories = $self->species_directories();
	    foreach my $dir (@$species_directories) {
		
		mkpath("$root/by_species/$species/$strain/$version/$dir",
		       { verbose => $self->debug,
			 mode    => 0775,
		     });		   
	    }
	}
	
	# Symlink to the current version. This really belongs in
	# mirroring and updating code.    

	# Create README stubs.
	# Create VERSION stubs.

	# etc, etc, etc
	
    }
}


# Mirror a file via HTTP.
# This should be cleaned up.

# Need lots of things to mirror a file.
# A repository object
# A mech agent
# Base destination path
# The destination filename
# The url of the file
sub mirror_file_by_http {
    my ($self,$mech,$path,$filename,$url) = @_;

    $self->establish();  # Just in case we're called from elsewhere.
    
    my $root = $self->root;    

    # By default, we mirror files to species/strain/raw.
    # I'm not certain this is optimal.
    # Should prob be a constructor for this.
    my $full_path = "$root/by_species/$path";
    mkpath($full_path,
	   { verbose => $self->debug,
	     mode => 0775,
	 });
    

    if ($self->debug) {
	$self->log->debug("Since we are in debug mode, we won't actually download $filename to $path...");
    } else {
	my $response = $mech->mirror($url,"$full_path/$filename");
	
	if ( $response->is_success() ) {
	    $self->log->info("successfully mirrored $filename to $full_path");
	} else {
	    $self->log->die("Crap. Something went wrong mirroring $filename at $url");
	}
    }
}





no Moose;

1;
