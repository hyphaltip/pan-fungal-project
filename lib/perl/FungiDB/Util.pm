package FungiDB::Util;

use Moose;
extends 'FungiDB';

# Generate suitable configuration 
sub generate_eupath_config {
    my $self = shift;
    
    # Crawl the data directory.
    my $repository = $self->repository;  # This is repo object

    my @species = $repository->crawl;
    


}



no Moose;

1;
