package FungiDB::Roles::Organism;

use Moose::Role;

has 'genus' => (is => 'ro',
		lazy_build => 1);

has 'species' => ( is => 'ro',
		   lazy_build => 1);

has 'symbolic_name' => (is => 'ro',
		     lazy_build => 1);

has 'source' => (is => 'ro',
		 lazy_build => 1);

has 'strains' => (is => 'ro',
		  lazy_build => 1);

has 'index_url' => (is => 'ro',
		    lazy_build => 1);
	
has 'file_template' => (is => 'ro',
			lazy_build => 1);

has 'version' => (is => 'rw',
		  lazy_build => 1);


sub _build_source {
    my $self = shift;
    my $name = $self->symbolic_name;

    my $source = $self->config->{organism}->{$name}->{source};
    
    # Really, this will be a singleton. 1 organism = 1 source.
    my @objects = $self->_source_factory($source);
    return $objects[0];
}

sub _build_symbolic_name {
    my $self = shift;
    return join('_',lc($self->genus),$self->species);
}

sub _build_file_template {
    my $self = shift;
    my $name = $self->symbolic_name;
    return $self->config->{organism}->{$name}->{file_template};
}

sub _build_index_url {
    my $self = shift;
    my $name = $self->symbolic_name;
    return $self->config->{organism}->{$name}->{index_url};
}

# Strain should probably be an object
sub _build_strains {
    my $self = shift;
    my $name = $self->symbolic_name;
    
    # For now, just symbolic names
    my @strains = keys %{$self->config->{organism}->{$name}->{strain}};
    return \@strains;
}

no Moose;


1;
