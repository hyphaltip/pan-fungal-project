#!/usr/bin/perl -w

# TODO: Add Lineage info
# See about Teleomorph/anamorph query
# Add prefixes
use strict;

use Bio::DB::Taxonomy;
use Bio::Tree::Tree;
use POSIX;
use DB_File;
use Date::Manip;
use File::Spec;
use XML::Twig;
use XML::Writer;
use HTML::Entities;
use Getopt::Long;
my %cache;
my $idxfile = '/tmp/cache_orgstrain.idx';
my $force;

GetOptions(
	  'f|force' => \$force,
	   );
if( $force ) {
    unlink($idxfile);
}
my $cachefh = tie(%cache,'DB_File',$idxfile,O_CREAT|O_RDWR, 
		  0666, $DB_HASH);
my $DEBUG = 0;
my $taxdir = '/data/databases/taxonomy';
my $taxdb = Bio::DB::Taxonomy->new(-source => 'flatfile',
                                   -nodesfile => File::Spec->catfile
                                   ($taxdir,'nodes.dmp'),
                                   -namesfile => File::Spec->catfile
                                   ($taxdir,'names.dmp'),
                                   -directory => $taxdir,
                                   );

my $base = '/project/genome_files';
my %exe = ('gz'  => 'zcat ',
	   'bz2' => 'bzip2 -c');

my %templates = ('source' => 'sources.txt',
		 'image'  => 'images.txt');

my %ext = ( 'ncbi' => qr/\.(gbk)(?:\.(gz|bz2))?$/ );

opendir(BASE,$base) || die "Cannot open $base: $!";
for my $king ( readdir(BASE) ) {
    next if $king =~ /^\./;
    my $kingdir = File::Spec->catdir($base,$king);
    next if( $DEBUG && $king ne 'fungi');
    next if ! -d $kingdir;    
    opendir(KINGDOM, $kingdir) || die "Cannot open $kingdir: $!";    
    for my $sp ( readdir(KINGDOM) ) {
	next if( $sp =~ /^\./);
	warn("sp is $sp\n") if $DEBUG;
	
	my $sppath = File::Spec->catdir($kingdir,$sp);	
	next unless -d $sppath;
	opendir(SP,$sppath) || die $!;
	my %strains;
	my ($org_full);
	for my $straind ( readdir(SP) ) {
	    next if $straind =~ /^\./;	
	    warn("strain is $straind\n") if $DEBUG;
	    my $raw = File::Spec->catdir($sppath,$straind,'raw');
	    next unless ( -d $raw );
	    opendir(RAW,$raw) || die "Cannot open dir $raw: $!";
	    #	print "$raw\n";	
	    for my $rawdir ( readdir(RAW) ) {
		next if( $rawdir =~ /^\./);		
		if( $rawdir =~ /ncbi/i ) {
		    my $rawd = File::Spec->catdir($raw,$rawdir);
		    opendir(NCBI,$rawd) || die "Cannot open dir $rawd: $!";
		    for my $ver ( readdir(NCBI) ) {		    
			next if( $ver =~ /^\./);
			warn("ver is $ver\n") if $DEBUG;
			# open
			my $verd = File::Spec->catdir($rawd,$ver);
			if( -d $verd ) {			
			    opendir(VER, $verd) || die "Cannot open dir $verd: $!";
			    my (%dates,$error);
			    for my $file ( readdir(VER) ) {	
				next if $file =~ /^\./;
				warn("file is $file\n") if $DEBUG;
				if( $file =~ $ext{$rawdir} ) {
				    # print "file is $file\n";
				    my $fullfile = File::Spec->catfile($verd,$file);
				    my ($ext,$cmp) = ($1,$2);
				    my $fh;
				    if( $cmp ) {
					open($fh, "$exe{$cmp} $fullfile |") || die "$exe{$cmp} $fullfile: $!";
				    } else {
					open($fh, "< $fullfile") || die "$fullfile: $!";
				    }
				    while(<$fh>) {
					if( /^LOCUS\s+(.+)/ ) {
					    my @all = split(/\s+/,$1);
					    $dates{pop @all}++;
					} elsif(/^\s{2}ORGANISM\s+(.+)/) {
					    my ($org) = $1;
					    if( defined $org_full && 
						$org ne $org_full ) {
						my ($g,$sp,$st) = split(/\s+/,$org,3);
						my ($g2,$sp2,$st2) = split(/\s+/,$org_full,3);
						if( $g eq $g2 &&
						    $sp eq $sp2 ) {
						    if( $st && ! $st2 ) {
							$org_full = $org;
						    }
						} else {
						    warn("see $org, expected $org_full\n");
						    warn("Mixed species in gbk files for $verd\n");
						    $error = 1;
						}
					    }
					    $org_full = $org;
					}
				    }
				}
			    }
			    closedir(VER);
			    my ($date) = ( map {$_->[0] }
					   sort { Date_Cmp($b,$a) }
					   map { [$_, ParseDate($_) ] } keys %dates);
			    $strains{$straind}->{'date'} = $date;
			    if( $error ) {
				warn("Something wrong with $verd\n");
				next;
			    } 
			}
		    }		    
		    closedir(NCBI);
		} elsif( $rawdir =~ /jgi/i ) {
		    
		} elsif( $rawdir =~ /tigrxml/i ) {
		    
		}
	    }
	    closedir(RAW);
	
	    my $indexfile = File::Spec->catfile($sppath,'INDEX.xml');
	    my $organism_ref = {};
	    if( -f $indexfile ) {
		# parse the XML
		my $xs = XML::Simple->new();
		my $index_ref = $xs->XMLin($indexfile);
		$organism_ref = $index_ref->{'organism'};
	    }
	    my $outfh;
	    open($outfh, ">$sppath/INDEX2.xml");
	    warn("org is $org_full\n");
	    my $writer = new XML::Writer(OUTPUT => $outfh,
					 DATA_MODE => 1,
					 DATA_INDENT => 1);
	    my ($genus,$species,$strain) = split(/\s+/,$org_full,3);
	    if( ! $species ) {
		warn "cannot parse $org_full\n";
	    }
	    my $ncbi_taxid = $taxdb->get_taxonid("$genus $species");
	    my $strain_ncbi_taxid = $taxdb->get_taxonid($org_full);
	    my $taxnode = $taxdb->get_Taxonomy_Node(-taxonid=>$strain_ncbi_taxid);
	    my $tree_functions = Bio::Tree::Tree->new();
	    my @lineage = $tree_functions->get_lineage_nodes($taxnode);
	    
	    $writer->startTag('organism',
			      'id' => $sp);			
	    if( exists $organism_ref->{'image'} ) {
		for my $image ( @{$organism_ref->{'image'}} ) {
		    $writer->emptyTag('image',%{$image});
		}
	    } else {
		$writer->emptyTag('image',
				  'src'         => '',
				  'credit_link' => '',
				  'credit'      => '');
	    }
	    
	    $writer->startTag('taxonomy',
			      'ncbi_taxa_id' => $ncbi_taxid);
	    
	    for my $n ( @lineage ) {
		next if $n->rank eq 'no rank';
		$writer->startTag($n->rank);
		$writer->characters($n->node_name);
		$writer->endTag($n->rank);
	    }
	    
	    {	# non Taxonomy queryable fields
		my $taxon = $organism_ref->{'taxonomy'};
		for my $field ( 
				qw(anamorph teleomorph variety sub_species) ) {
		    if( exists $taxon->{$field} && 
			defined $taxon->{$field} ) {
			$writer->startTag($field);
			$writer->characters($taxon->{$field});
			$writer->endTag($field);
		    } else {
			$writer->emptyTag($field);
		    }
		}
	    }
	    $writer->endTag('taxonomy');
	    
	    # strains
	    $writer->startTag('strains');
	    # foreach strain
	    for my $strain ( keys %strains ) {
		my ($date) = $strains{$strain}->{'date'};
		$writer->startTag('strain',
				  'id' => $strain,
				  'ncbi_taxa_id' => $strain_ncbi_taxid);
		# strain aliases
		$writer->startTag('strain_aliases');
		$writer->emptyTag('strain_alias');
		$writer->endTag('strain_aliases');
		
		# sequence information
		$writer->startTag('sequence_collection',
				  'type' => "genomic");
		$writer->emptyTag('external_version',
				  'id'   => $date,
				  'src'  => 'NCBI',
				  'date' => $date,
				  );
		$writer->emptyTag('internal_version',
				  'id'   => 1,
				  'date' => strftime("%d-%b-%Y",localtime()));
		$writer->startTag('source');
		if( exists $organism_ref->{'source'} ) {
		    for my $o ( @{$organism_ref->{'organization'}} ) {
			$writer->startTag('organization');
			$writer->characters($o);
			$writer->endTag('organization');
			
			$writer->emptyTag('url',
					  'source' => '',
					  'type'   => '',
					  'href'   => '');
		    }
		} else {
		    $writer->startTag('organization');
		    $writer->endTag('organization');			
		    $writer->emptyTag('url',
				      'source' => '',
				      'type'   => '',
				      'href'   => '');
		    $writer->endTag('source');
		}
		my $short = sprintf("%s%s_%s",lc(substr($genus,0,1)),
				    substr($species,0,3),
				    $strain);
		my $prefix = "$genus\_$species\_$straind";
		$writer->emptyTag('prefix',
				  'short' => $short,
				  'filename' => $prefix);
		$writer->startTag('prefix_aliases');
		$writer->startTag('prefix_alias');
		$writer->endTag('prefix_alias');
		$writer->endTag('prefix_aliases');
		
		$writer->endTag('sequence_collection');
		$writer->endTag('strain');
	    }
	    $writer->emptyTag('primary_strain',
			      'id' => $straind);
	    $writer->endTag('strains');
	    $writer->endTag('organism');
	    $writer->end();
	    
#				print "$org_full and $date\n";
	    
	}
	closedir(SP);
	last if $DEBUG;
    }
    closedir(KINGDOM);
    last if $DEBUG;
}

# old stuff for parsing INDEX file
#    my $indexfile = File::Spec->catfile($kingdir,'INDEX.xml');
#    if( -f $indexfile ) {
#	# parse the XML
#	my $twig = XML::Twig->new( twig_handlers =>
#				   { },
#				   pretty_print => 'indented',                # output will be nicely formatted
#				   empty_tags   => 'html',                    # outputs <empty_tag />
#                                );
	# flush the end of the document
#	$twig->parsefile($indexfile);
#	my $root= $twig->root;
#	my @orgs = $root->children('organism');
#	foreach my $o (@orgs) {
#	    $o->print;
#	    print "\n";
#	    print Dumper($o);
#	}
#    }
