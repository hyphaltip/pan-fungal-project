package FungiDB::Roles::Source;

use Moose::Role;


has 'symbolic_name' => ( is  => 'rw',
#		isa => 'Str',
		);

has 'title' => ( is  => 'ro',
#		 isa => 'Str',
		 lazy_build => 1,
		 );

has 'organisms' => (is => 'ro',
		    lazy_build => 1);

#has 'source'    => (is => 'ro',
#		    lazy_build => 1);#


sub _build_organisms {
    my $self = shift;
    my $name = $self->symbolic_name;  # The symbolic name of the source; MUST match source entry for the organism. 
    
    # Fetch all organisms that this center is responsible for.
    my @organisms = grep { $self->config->{organism}->{$_}->{source}  eq "$name" } keys %{$self->config->{organism}};
    
    # Return an array of FungiDB::Organism::* objects
    my @objects = $self->_organism_factory(@organisms);
    return \@objects;
}


sub _build_title {
    my $self = shift;
    my $name = $self->symbolic_name;
    my $title = $self->config->{source}->{$name}->{title};
    return $title;
}


no Moose;

1;
