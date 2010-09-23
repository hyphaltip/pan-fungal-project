package FungiDB::Organism;

use Moose;
extends 'FungiDB';


has'genus' => (is => 'ro',
	       );

has 'species' => ( is => 'ro'
		   );

has 'source' => (is => 'ro',
		 isa => 'FungiDB::Source',
		 lazy_build => 1,
		 );


sub _build_source {
    my $self = shift;
    my $name = $self->name;
    
    my $class = FungiDB::Source->create($self->config->{$name}->{source}));
    return $class;
};					   



no Moose;


1;
