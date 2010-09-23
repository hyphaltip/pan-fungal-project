package FungiDB::Source;

use Moose;
use FungiDB::Factory;
extends 'FungiDB';


has 'name' => (is => 'rw',
	       );



has 'source' => (is => 'ro',
		 lazy_build => 1,
		 );


sub _build_source {
    my $self = shift;
    my $name = $self->name;
    
    my $class = FungiDB::Factory->create($name);
    return $class;
};					   



no Moose;


1;
