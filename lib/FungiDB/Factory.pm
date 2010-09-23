package FungiDB::Factory;
use MooseX::AbstractFactory;

# Roles that the factory should implement:
implementation_does qw/FungiDB::Roles::Source/;

# Generate the appropriate class name
implementation_class_via sub { 'FungiDB::Sources::' . shift };

1;
