package FungiDB;

use Moose;
use Config::General;
use Cwd;
use FungiDB::Factory;
use File::Spec;
use Log::Log4perl;

has 'config' => (
		 is  => 'rw',
		 isa => 'HashRef',		
		 );

has 'organisms' => (
		    is  => 'ro',
		    isa => 'ArrayRef',
		    lazy_build => 1,
		    );

has 'sources' => ( 
		   is => 'ro',
		   isa => 'ArrayRef',   # ArrayRef of FungiDB::Source::* objects
		   lazy_build => 1
		   );

has 'log' => ( is => 'ro',
	       lazy_build => 1);

has 'debug' => ( is => 'rw',
		 default => 0);


has 'version_history' => ( is => 'rw',
			   lazy_build => 1);




# After instantiation, load up our new object with our Config::General
sub BUILD {
    my $self = shift;

    # This is a dumb way of doing this.
    my $cwd = cwd();
    my $conf   = new Config::General(-ConfigFile      => "$cwd/conf/fungidb.conf",
				     -IncludeGlob     => "$cwd/conf/organisms.conf",
				     -InterPolateVars => 1) or die "Whoops. Couldn't load the config file";    
    my %config = $conf->getall;
    $self->config(\%config);
}

sub _build_log {
    my $self = shift;
    my $cwd = cwd();
    Log::Log4perl::init("$cwd/conf/log4perl.conf") or die "couldn't instantiate my logger";
    my $log = Log::Log4perl::get_logger();
    return $log;
}



# Extract available organisms from config; kinda annoying.
sub _build_organisms {
    my $self = shift;
    my @organisms = keys %{$self->config->{organism}};

    # Return an array of objects
    my @objects = $self->_organism_factory(@organisms);
    return \@objects;
}

sub _build_sources {
    my $self = shift;
    
    # Fetch the symbolic name of all sources
    my @sources = keys %{$self->config->{source}};

    # Create FungiDB::Source::* objects from them all
    my @objects = $self->_source_factory(@sources);
    return \@objects;
}





# A factory for a single source
sub source {
    my $self = shift;
    my $name = shift;
    my @sources = $self->_source_factory($name);
    return $sources[0];
}


# A factory for a single organism
sub organism {
    my $self = shift;
    my $name = shift;
    my @organisms = $self->_organism_factory($name);
    return $organisms[0];
}

sub repository {
    my $self = shift;
    my $args = $self->config->{repository};
    my $repository = $self->factory("Repository",$args);
}    


sub factory {
    my $self = shift;
    my ($class,$args) = @_;

    # Sorry, this factory is rather opaque.
    # Using the super class to delegate to subclasses isn't great design
    # but makes for easy downstream scripts.
    my $object = FungiDB::Factory->create($class,
					  $args
					  );
    return $object;
};


sub _organism_factory {
    my ($self,@organisms) = @_;
    my @objects;
    foreach (@organisms) {
	# Pass the configuration data hash directly
	my $args = $self->config->{organism}->{$_};
	push @objects,$self->factory("Organism::$_",$args);
    }
    return @objects;
}


sub _source_factory {
    my ($self,@sources) = @_;
    my @objects;
    foreach (@sources) {

	my $args = $self->config->{source}->{$_};
#	$args->{name} = $_;
	push @objects,$self->factory("Source::$_",$args);
    }
    return @objects;
}



# First request? Get the values from the 
sub _build_version_history {    
    my ($self,$data) = @_;
    
    my $cwd = cwd();

    my $log_file = "$cwd/logs/update.log";
    unless (-e $log_file) {
	system("touch $log_file");
    }

    open my $log, '<',$log_file or die "Couldn't open the update.log: $!";
    
    my @cols = qw/
	species
	strain
	current_version
	date_last_checked
	date_last_updated	
	/;
    
    my %species;
    while (<$log>) {
	my @fields = split("\t");
	my $c = 0;

	# ugh
	my %data;
	foreach (@cols) {
	    $data{$_} = $fields[$c];
	    $c++;
	}
	$species{$fields[2]} = %data;
    }
}


# One line per file. Not ideal ATM but okay for now.
sub dump_version_history { 
    my ($self,$data) = @_;
    my $cwd = cwd();
    my $date = `date +%Y-%m-%d`;
    chomp $date;
    $data->{date} = $date;
    
    my @fields = qw/date species strain version source path filename/;
    

    my $log_file = "$cwd/lib/update.log";
    unless ( -e $log_file) {
	system("touch $log_file");
	open my $log, '>',"$log_file" or die "Couldn't open the species_update.log: $!";
	print $log join("\t",@fields). "\n";
	close $log;
    }
    
    open my $log, '>>',"$log_file" or die "Couldn't open the species_update.log: $!";    
    print $log join("\t",map { $data->{$_} } @fields) . "\n";
}





sub check_for_updates {
    my ($self,$data) = @_;
    my $species = $data->{species};

    my $version_history = $self->version_history;
    
    # What's the previous version?
    my $previous_version = $version_history->{$species}->{version};
    if ($data->{version} > $previous_version) {
	
	# We've been updated. Save.
#	$self->_save_update
	
	
    } else {
	return 0;
    }

}




1;
