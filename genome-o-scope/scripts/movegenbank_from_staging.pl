#!/usr/bin/perl -w
use strict;
use File::Spec;
use Bio::DB::Taxonomy;
use Bio::Tree::Tree;
use Date::Manip;
use File::Copy qw(move copy);
use File::Path;
use DB_File;
use Getopt::Long;
use File::Rsync;

my $SEP = ':';

my ($force,$debug);
GetOptions(
	   'f|force' => \$force,
	   'd|debug' => \$debug,
	   );

if( $force ) {
    unlink('/tmp/cache.idx');
}
my (%cache);
my $cacheh = tie(%cache, 'DB_File', '/tmp/cache.idx',O_CREAT|O_RDWR, 
		 0666, $DB_HASH);
my %exe = ('bz2' => '/usr/bin/bzip2 -c',
	   'gz'  => '/bin/zcat',
	   'Z'   => '/bin/zcat');

my $taxdir = '/data/databases/taxonomy';
my $taxdb = Bio::DB::Taxonomy->new(-source => 'flatfile',
                                   -nodesfile => File::Spec->catfile
                                   ($taxdir,'nodes.dmp'),
                                   -namesfile => File::Spec->catfile
                                   ($taxdir,'names.dmp'),
                                   -directory => $taxdir,
                                   );

my $dest_dir = '/project/genome_files/fungi';
my $staging_dir = shift || '/tmp/genbank_staging';

opendir(DIR,$staging_dir) || die "$staging_dir : $!";
for my $dir ( readdir(DIR) ) {
    next if ($dir =~ /^\./);
    my $stage = File::Spec->catdir($staging_dir, $dir);
    next unless -d $stage;
    my (%r);
    opendir(DIR2,$stage) || die "$stage: $!";
    for my $file ( readdir(DIR2) ) {
	next unless ($file =~ /^(\S+)\.gbk(?:\.(gz|bz2|Z))?/);
	my ($accbase,$ext) = ($1,$2);
	my $fh;
	
	my $fullpath = File::Spec->catfile($stage,$file);
	my ($org,$date);
	if( $cache{$accbase} ) {
	    ($org,$date) = split(/$SEP/,$cache{$accbase});
	} else {
	    ($org,$date) = &get_info($fullpath);
	    next unless $org;
	    $cache{$accbase} = join($SEP,($org,$date));
	}
	next unless( $org );
	push @{$r{$org}}, [$date,$fullpath,$file];
    }

    while( my ($org_full,$files) = each %r ) {
	my %dates = map { $_->[0] => 1 } @{$files};
	my ($version) = ( map {$_->[0] }
			  sort { Date_Cmp($b,$a) }
			  map { [$_, ParseDate($_) ] } keys %dates);
	
	my $strain_ncbi_taxid = $taxdb->get_taxonid($org_full);
	my $taxnode = $taxdb->get_Taxonomy_Node(-taxonid=>$strain_ncbi_taxid);
	my $tree_functions = Bio::Tree::Tree->new();
	my @lineage = $tree_functions->get_lineage_nodes($taxnode);
	# this is madness - we have to infer the strain by SUBTRACTING
	# the last node (species) node string from the full taxnode name
	my $species_node;
	for my $node ( @lineage ) {
	    if( $org_full !~ /var\. neoformans/ &&
		$node->rank eq 'species' ) {
		$species_node = $node;
		last;
	    } elsif( $org_full =~ /neoformans/ ) {
		$species_node = $node;
	    }
	}
	
	my $strain;
	$species_node = $taxnode unless defined $species_node;
	my ($species_name) = @{$species_node->name('scientific')};
	my ($taxnode_name) = @{$taxnode->name('scientific')};
	
	if( $strain_ncbi_taxid == 284811 ) {
	    $strain = 'ATCC 10895';
	} elsif( $strain_ncbi_taxid == 294750 ) {
	    $strain = 'R265';
	} elsif( $strain_ncbi_taxid == 5062 ) {
	    $strain = 'RIB40';
	} else {
	    $strain = substr($taxnode_name, 
			 length($species_name)+1);
	}
	# deal with C_neoformans_var\._neoformans
	$species_name =~ s/\.//g;    
	$strain =~ s/^\s+//;
	$strain =~ s/\s+$//;
	$strain =~ s/\s+/_/g;
	$strain =~ s/\.//g;
	my @values =  @{$r{$org_full}};
	my $sname = $species_name;
	$sname =~ s/\s+/_/g;
	print $sname, ": $org_full; $strain_ncbi_taxid; '$strain'\n";
	my $d = File::Spec->catfile($dest_dir,
				$sname,
				    $strain,
				    'raw',
				    'ncbi',
				    $version,
				    );
	print "$d\n";
	mkpath($d);
	for my $f ( @{$files} ) {
	    next if -f "$d/".$f->[2];
	    my $fsrc = $f->[1];
	    my $fdest = $f->[2];
	    `rsync $fsrc $d/$fdest`;
	    # copy($fname,$d);
	}
    }
}

sub get_info {
    my $file = shift;
    my ($acc,$ext);
    if($file =~ /^(\S+)\.gbk(?:\.(gz|bz2|Z))?/) {
	($acc,$ext) = ($1,$2);
    } else {
	warn("Cannot read ACC and EXT from $file\n");
	return;
    }
    my $fh;
    if( $ext ) {
	open($fh, "$exe{$ext} $file |") || die "$exe{$ext} $file: $!";
    } else {
	open($fh, "< $file") || die "$exe{$ext} $file: $!";
    }
    
    my ($org_full, $date,$error);
    while(<$fh>) {
        if( /^LOCUS\s+(.+)/ ) {
            my @all = split(/\s+/,$1);
            $date = pop @all;
        } elsif( /^DEFINITION/ ) {
            return '' if /mitochondrion|mitochondrial/;
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
                    warn("See $org, expected $org_full\n");
                    warn("Mixed species in gbk files for $file\n");
                    $error = 1;
                }
            }
            $org_full = $org;
        }
    }
    return ($org_full,$date);
}
