#!/usr/bin/perl -w

# Establish a new repository.

use strict;
use FungiDB::Organize::Repository;

my $repository = FungiDB::Organize::Repository->new();

$repository->establish;


