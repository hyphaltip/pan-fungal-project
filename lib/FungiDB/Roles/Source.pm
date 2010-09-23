package FungiDB::Roles::Source;

use Moose::Role;

has 'name' => ( is  => 'rw',
#		isa => 'Str',
		);

has 'title' => ( is  => 'ro',
#		 isa => 'Str',
		 lazy_build => 1,
		 );

sub _build_title {
    my $self = shift;
    my $name = $self->source;
    my $title = $self->config->{sources}->{$name}->{title};
    return $title;
}


no Moose;

1;
