package FungiDB::Roles::Organism;

use Moose::Role;

has 'genus' => (is => 'ro',
		required => 1,
		);

has 'species' => ( is => 'ro'
		   );

has 'index_name' => (is => 'ro',
		   lazy_build => 1);

has 'source' => (is => 'ro',
		 lazy_build => 1,
		 );
has 'strains' => (is => 'ro',
		  lazy_build => 1,);

sub _build_source {
    my $self = shift;
    my $name = $self->index_name;

    my $source = $self->config->{organism}->{$name}->{source};
    
    # Really, this will be a singleton. 1 organism = 1 source.
    my @objects = $self->_source_factory($source);
    return $objects[0];
}

sub _build_index_name {
    my $self = shift;
    return join('_',lc($self->genus),$self->species);
}

# Strain should probably be an object
sub _build_strains {
    my $self = shift;
    my $name = $self->index_name;
    
    # For now, just symbolic names
    my @strains = keys %{$self->config->{organism}->{$name}->{strain}};
    return \@strains;
}

no Moose;


1;
