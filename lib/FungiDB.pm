package FungiDB;

use Moose;
use Config::General;
use Cwd;
use FungiDB::Factory;
use File::Spec;

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



# After instantiation, load up our new object with our Config::General
sub BUILD {
    my $self = shift;

    # This is a dumb way of doing this.
    my $cwd = cwd();
    my $conf   = new Config::General("$cwd/conf/fungidb.conf") or die "Whoops. Couldn't load the config file";    
    my %config = $conf->getall;
    $self->config(\%config);
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


sub _factory {
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
	push @objects,$self->_factory("Organism::$_",$args);
    }
    return @objects;
}


sub _source_factory {
    my ($self,@sources) = @_;
    my @objects;
    foreach (@sources) {

	my $args = $self->config->{source}->{$_};
#	$args->{name} = $_;
	push @objects,$self->_factory("Source::$_",$args);
    }
    return @objects;
}










1;
