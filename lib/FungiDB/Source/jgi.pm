package FungiDB::Source::jgi;

use Moose;

with 'FungiDB::Roles::Source';
extends 'FungiDB';

has => 'species_list' ( is => 'ro',
			lazy_build => 1);


sub species_list {
    my $self = shift;
    my $name = $self->symbolic_name;
    my $url  = $self->config->{source}->{$name}->{species_xls_url};
    my $repository = $self->repository;

    $repository->mirror_file_by_http($mech,
				     $repository->log,
				     'jgi-genome-projects.xls',
				     $url);

    
}



1;
