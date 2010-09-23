package FungiDB;

use Moose;
use Config::General;
use FindBin qw/$Bin/;

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
		   isa => 'ArrayRef',
		   lazy_build => 1
		   );


# Extract available organisms from config; kinda annoying.
sub _build_organisms {
    my $self = shift;
    my @organisms = keys %{$self->config->{organisms}};
    return \@organisms;
}

sub _build_sources {
    my $self = shift;
    my @organisms = keys %{$self->config->{sources}};
    return \@organisms;
}



# Load up our newly instantiated object with our Config::General
sub BUILD {
    my $self = shift;
    my $conf   = new Config::General("$Bin/../conf/species.conf") or die "Whoops. Couldn't load the config file";    
    my %config = $conf->getall;
    $self->config(\%config);
}


1;
