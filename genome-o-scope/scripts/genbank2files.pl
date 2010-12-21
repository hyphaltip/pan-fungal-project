#!/usr/bin/perl -w
use Env qw(HOME);
# author Jason Stajich <jason.stajich@ucr.edu>

=head1 NAME

genbank2files --basedir /project/genome_files/fungi

This will write out GFF3, NT, PEP, INTRON, and CDS files where needed

=cut

use strict;
use lib "$HOME/src/bioperl/dev";
use Bio::SeqFeature::Slim; # for speed -- this is from github.com/bioperl/bioperl-dev
#use Bio::SeqFeature::Generic;
use Bio::SeqIO;
use Getopt::Long;

use Bio::Tools::GFF;
use Date::Manip;
use File::Spec;
use Bio::SeqFeature::Tools::Unflattener;

use constant MRNA => 'mRNA';
use constant GENE => 'gene';
use constant CDS  => 'cds';
use constant EXON  => 'exon';
use constant UTR5  => 'five_prime_utr';
use constant UTR3  => 'three_prime_utr';

use constant MIN_LENGTH => 10_000;

my %Seq_File = map { $_ => "$_.fasta" } qw(cds nt pep intron gene);
my $gff_ext = 'gff3';
my $gff_version = 3;
my $informat ='genbank';
my $seqformat =  'fasta';
my $source    = 'NCBI';
my $src_dir = File::Spec->catdir(qw(raw ncbi));

my %uncomp = ('gz' => '/bin/zcat',
	      'Z' => '/bin/zcat',
	      'bz2' => '/usr/bin/bunzip2 -c',
	      );
my $SRC = "genbank";

my ($force,$basedir,$debug,$allversions) = (0,undef,0,undef);

GetOptions('f|force' => \$force,
	   'v|verbose|debug!' => \$debug,
	   'h|help' => sub { exec('perldoc', $0);
               exit(0);
           },
	   'all|allversions' => \$allversions,
	   'b|basedir:s'     => \$basedir,
	   );
die("need a basedir") unless $basedir && -d $basedir;

# needed globally
my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;
$unflattener->error_threshold(1);
$unflattener->report_problems(\*STDERR);

opendir(DIR,$basedir) || die "$basedir: $!";
SP: for my $species ( readdir(DIR) ) {
    next if $species =~ /^\./;    
    my $sppath = File::Spec->catdir($basedir,$species);
    warn("$sppath\n") if $debug;
    next unless -d $sppath;
    my ($genus,$spp) = split(/_/,$species);
    opendir(S,$sppath) || die "$sppath: $!";
    for my $strain ( readdir(S) ) {
	next if $strain =~ /^\./;
	my $straintmp = $strain;
	$straintmp =~ s/_//g;
	my $prefix = substr($genus,0,1).substr($spp,0,3). "_$straintmp";
	# skip files
	next if ! -d File::Spec->catfile($sppath,$strain); 
	warn(" ---> $strain\n") if $debug;
	
	# gotta have a proper raw/ncbi directory to proceed
	my $ncbipath = File::Spec->catfile($sppath,$strain,$src_dir);
	unless( -d $ncbipath ) {
	    warn("cannot file $src_dir in the directory $ncbipath\n");
	    next SP;
	}
	opendir(VERSIONS, $ncbipath) || die "$ncbipath: $!";
	my @versions;
	for my $ver ( readdir(VERSIONS) ) {
	    next if $ver =~ /^\./;
	    next unless -d File::Spec->catfile($ncbipath,$ver);
	    push @versions, $ver;
	}
	closedir(VERSIONS);
	for my $version ( sort { Date_Cmp($b,$a) } @versions ) {
	    my %files = 
		map { $_ => File::Spec->catfile($sppath,$strain,
						sprintf("%s_%s.%s.%s",
							$species,$strain,
							$version,
							$Seq_File{$_} )) } 
	    keys %Seq_File;
	    
	    if( $force || grep { ! -f $_ } values %files ) {
		warn("processing ... $species\_$strain.$version\n");
		# these are just internal counts that need to be 
		# unique for a given assembly/annotation nothing more
		my %counts = map { $_ => 0 } qw(gene mrna CDS exon intron);

		my %fh;
		# Now parse all genbank
		my $full_version = File::Spec->catfile($ncbipath,$version);
		opendir(VER, $full_version) || die $!;
		
		while( my ($filetype,$filename) = each %files ) {
		    $fh{$filetype} = Bio::SeqIO->new(-format => $seqformat,
						     -file   => ">$filename");
		}
		$fh{'gff'} = Bio::Tools::GFF->new
		    (-file =>		     
		     sprintf(">%s/%s_%s.%s.%s",
			     File::Spec->catfile($sppath,$strain),
			     $species,
			     $strain,
			     $version,
			     $gff_ext),
		     -gff_version => $gff_version);
		my @seqs;
		my %features;
		for my $file ( readdir(VER) ) {
		    next unless $file =~ /(\S+)\.gbk(?:\.(bz2|gz|Z))?/;
		    my ($stem,$extension) = ( $1,$2);
		    my $full_path = File::Spec->catfile($full_version,$file);
		    
		    my $fh;
		    if( $extension ) {
			open($fh, "$uncomp{$extension} $full_path |") || 
			    die "$full_path: $!";
		    } else {
			open($fh, "< $full_path") || die "$full_path: $!";
		    }
		    
		    my %features;
		    my $seqio = Bio::SeqIO->new(-format => $informat,
						-fh     => $fh);
		    while( my $seq = $seqio->next_seq ) {
			next if ! defined $seq->seq;
			my ($locus,$desc,$acc) = ( $seq->display_name,
					       $seq->description,
					       $seq->accession_number);
			my ($shortid,$id);
			if( $desc =~ /chromosome\s+(\S+)[,\.]/ ||
			    $desc =~ /chromosome\s+(\S+)\s+complete/ ||
			    $desc =~ /chromosome\s+((?:scaffold|cont\w+)\s*\S+)/ ) {
			    $shortid = $1;
			    $shortid =~ s/,(\s+complete)?\s*$//;
			    $id = "$prefix\_chr$shortid";
			    $id =~ s/\s+/_/g;
			    $shortid =~ s/\s+/_/g;
			} elsif( $desc =~ /(supercont(?:ig)?\s?\S+)/ ||
				 $desc =~ /Contig\[(\d+)\]/i ||
				 $desc =~ /(contig\s?\S+)/i ||
				 $desc =~ /(\S*Scaffold_?\S+)/i ||
				 $desc =~ /(cont\S+)/i ||
				 $desc =~ /clone\s+(\S+)/  ||
				 $desc =~ /genomic\s+scaffold\s+(\S+)/i
				 ) {
			    
			    $shortid = $1;
			    $shortid =~ s/\s+/_/g;
			    $id = join("_",$prefix,$shortid);
			
			} else {
			    $id = $acc;
			    $shortid = $id;
			    warn("cannot determine a good name for $locus;$desc;$full_path\n");
			}
			for my $i ( $id, $shortid ) {
			    $i =~ s/[_\.,:;\s]+$//;
		        }
			if( $shortid eq 'scaffold' || $shortid eq 'contig' ) {
                              $shortid = $acc;
                              $id = $acc;
			}

			$seq->display_id($id);
			$acc = sprintf("%s.%d",$acc,$seq->version);
			$seq->accession_number($acc);
			$seq->description($acc);
			push @seqs, $seq;
			$fh{'gff'}->write_feature
			    (Bio::SeqFeature::Slim->new
			     (-seq_id => $id,
			      -start  => 1,
			      -end    => $seq->length,
			      -source_tag => 'assembly',
			      -primary_tag  => 'chromosome',
			      -tag => 
			      { 'ID' => $id,
				'Accession' => $acc,
				'Name' => $id, 
				'Alias' => $shortid,
			    },
			      ));
			 &extract_features($seq,$prefix,\%fh,\%counts);
		    }
		    close($fh);
		}
		for my $seq ( map { $_->[0] }
			      sort { $b->[1] <=> $a->[1] } 
			      map { [$_, $_->length] } 
			      @seqs ) 
		{		    
		    $fh{'nt'}->write_seq($seq);
		    warn("wrote seq ",$seq->id,"\n") if $debug;
		}
		last if $debug > 1;
	    } else {
		warn("skipping ... $species\_$strain.$version\n");
	    }
	    last unless $allversions;
	}
	last if $debug > 1;
    }
    closedir(S);
    last if $debug > 1;
}
closedir(DIR);

sub extract_features {
    my ($seq,$prefix,$fh,$counts) = @_;
    my $seq_id = $seq->display_id;
    $unflattener->unflatten_seq(-seq=>$seq,
				-group_tag=>'locus_tag',
				-use_magic=>1);
    my @features;
    for my $f ( map { $_->[0] }
		sort { $a->[1] <=> $b->[1] }
		map { [$_,$_->start] } $seq->get_SeqFeatures ) {
	my $primarytag = $f->primary_tag;
	
	next unless $primarytag eq 'gene';
	next if $f->has_tag('pseudo');

	my $genestr;
	my ($min,$max,$strand) = ($f->start,$f->end, $f->strand);
	my ($pname,%genexrefs, @genexrefs_a);

	if( $f->has_tag('db_xref') ) { 
	    for my $xref ( $f->get_tag_values('db_xref') ) {
		my ($xref_src,$xref_id) = split(':',$xref);
		$genexrefs{$xref_src} = $xref_id;
		push @genexrefs_a, &escape($xref);
	    }
	}
	for my $ptag ( qw(locus_tag gene name) ) {
	    if( $f->has_tag($ptag) ) {
		($pname) = $f->get_tag_values($ptag);
		last;
	    }
	}
	my @old_tags;
	if( $f->has_tag('old_locus_tag') ) {
	    push @old_tags, $f->get_tag_values('old_locus_tag');
	}
	$pname = $genexrefs{GeneID} if( exists $genexrefs{'GeneID'} && 
					! defined $pname);

	unless( defined $pname ) {
	    warn("cannot find pname in ", $f->gff_string, "\n");
	    last;
	}
	my $unique_geneid = sprintf("gene%06d",$counts->{'gene'}++);
	my $genef = Bio::SeqFeature::Slim->new(-seq_id => $seq_id,
					       -source => $source,
					       -primary=> GENE,
					       -start  => $f->start,
					       -end    => $f->end,
					       -strand => $f->strand,
					       -tag    => { 
						   'ID' => $unique_geneid,
						   'Name'  => "$pname",
						   'Alias' => "$pname",
				   });
	if( @genexrefs_a ) {
	    $genef->add_tag_value('Dbxref', @genexrefs_a);
	}
	if( @old_tags ) {
	    $genef->add_tag_value('Old_locus_tag',@old_tags);
	}
	# lookahead and grab the notes from mRNAs 
	my @mrnas = grep {$_->primary_tag eq 'mRNA' } $f->get_SeqFeatures;
	for my $mRNA ( @mrnas ) {
	    my @note;
	    if( $mRNA->has_tag('note') ) {
		@note= $mRNA->get_tag_values('note');
	    }
	    if( $mRNA->has_tag('product') ) {
		unshift @note, $mRNA->get_tag_values('product');
	    }
	    @note = grep {! /^(predicted|hypothetical) protein/} @note;
	    $genef->add_tag_value('Note',&escape(@note)) if @note;
	}
	$fh->{'gff'}->write_feature($genef);
	my $geneseq = $seq->trunc($f->start,$f->end);
	$geneseq = $geneseq->revcom if $f->strand < 0;
	$geneseq->display_id("$prefix:$pname");
	$geneseq->description(sprintf("%s:%s",$seq_id,$f->location->to_FTstring));
	$fh->{'gene'}->write_seq($geneseq);
	
	my $mrnact = 0;
	# reprocess mRNAs fully
	for my $mRNA ( @mrnas ) {
	    my $mrna_name = $pname;
	    $mrna_name = "$pname"."T".$mrnact++;
 	    my $unique_mrnaid = sprintf("mrna%06d", $counts->{'mrna'}++);
	    my $mrnaf = Bio::SeqFeature::Slim->new(
					       -seq_id => $seq_id,
					       -source => $source,
					       -primary=> MRNA,
					       -start  => $mRNA->start,
					       -end    => $mRNA->end,
					       -strand => $mRNA->strand, 
					       -tag    => 
						   { 
						       'ID'     => $unique_mrnaid,						       
						       'Name'   => $mrna_name,
						       'Parent' => $unique_geneid,
					       });
	    
	    my %mRNAxref;
	    my @m_xrefs;
	    if( $mRNA->has_tag('db_xref') ) { 
		for my $xref ( $mRNA->get_tag_values('db_xref') ) {
		    my ($xref_src,$xref_id) = split(':',$xref);
		    $mRNAxref{$xref_src} = $xref_id;
		    push @m_xrefs, &escape($xref);
		}
	    }
	    
	    $mrnaf->add_tag_value('Dbxref',@m_xrefs) if @m_xrefs;
	    my @note;
	    if( $mRNA->has_tag('note') ) {
		@note= $mRNA->get_tag_values('note');
	    }
	    if( $mRNA->has_tag('product') ) {
		unshift @note, $mRNA->get_tag_values('product');
	    }
	    @note = grep {! /^(predicted|hypothetical) protein/} @note;
	    $mrnaf->add_tag_value('Note',&escape(@note)) if @note;
	    for my $t ( qw(protein_id transcript_id synonym) ) {
		if( $mRNA->has_tag($t) ) {
		    # warn("$t --> ", $f->get_tag_values($t), "\n");
		    $mrnaf->add_tag_value('Alias',
					  &escape( $mRNA->get_tag_values($t)));
		} elsif( $f->has_tag($t) ) {
		    $mrnaf->add_tag_value('Alias',
					  &escape( $f->get_tag_values($t)));  
		}
	    }
	    $fh->{'gff'}->write_feature($mrnaf);
	    # make a CDS
	    my (@e,%ecount);
	    my ($cdslen)=(0);
	    my ($start_codon,$stop_codon);
	    
	    my @exons = ( grep { $_->primary_tag eq 'exon' } 
			  $mRNA->get_SeqFeatures);
	    my @cds   = ( grep { $_->primary_tag eq 'CDS' } 
			  $mRNA->get_SeqFeatures);
	    my (@newcds,@newexons);
	    my $cds_str;
	    my $icount = 0;
	    my $last_cds;	    
	    my $ecount = 0;
	    for my $cds ( @cds) 
	    {
		my $type = lc $cds->primary_tag;
		for my $e ( sort { $a->start * $a->strand <=> $b->start * $b->strand } 
			    $cds->location->each_Location ) {
		    if( defined $last_cds ) {
			my $intronloc = Bio::Location::Simple->new(-strand => $e->strand);
			if( $intronloc->strand > 0 ) {
			    $intronloc->start($last_cds->end + 1);
			    $intronloc->end($e->start - 1);
			} else {
			    $intronloc->start($e->end + 1);
			    $intronloc->end($last_cds->start - 1);
			}
			if( $intronloc->start > $intronloc->end ) {
			    my $lst = $intronloc->start;
			    $intronloc->start($intronloc->end);
			    $intronloc->end($lst);
			}
			next if $intronloc->length <= 3;
			my $intron_str = $intronloc->strand > 0 ? 
			    $seq->subseq($intronloc->start,$intronloc->end) : 
			    $seq->trunc($intronloc->start,$intronloc->end)->revcom->seq;
			
			my $intron_s = Bio::PrimarySeq->new
			    (-display_id => sprintf("%s.i%s",$mrna_name,$icount++),
			     -seq => $intron_str,
			     -description=> sprintf("gene=%s %s:%s",
						    $pname,
						    $seq_id,
						    $intronloc->to_FTstring));
			$fh->{'intron'}->write_seq($intron_s);
		    }
		    $last_cds = $e;
		    $ecount++;
		    
		    my $frame = $cdslen % 3;
		    $cdslen += $e->length;
		    unless( defined $start_codon ) {
			$start_codon = ( $cds->strand > 0) ? $e->start : $e->end;
		    }
		    $stop_codon = ( $cds->strand > 0) ? $e->end : $e->start;
		    
		    push @newcds, Bio::SeqFeature::Slim->new
			(-seq_id => $seq_id,
			 -start  => $e->start,
			 -end    => $e->end,
			 -strand => $cds->strand,
			 -source => $source,
			 -primary=> $cds->primary_tag,
			 -frame  => $frame,
			 -tag    => { 
			     'ID'     => 
				 sprintf("%s%06d",
					 $type,
					 $counts->{$type}++),
				 'Parent'   => $unique_mrnaid,
				 'Name'     => 
				 sprintf("%s.%s%d",$mrna_name,
					 $type,++$ecount{$type}),
			     });
		    $cds_str .= $cds->strand > 0 ? $seq->subseq($e->start,$e->end) : 
			$seq->trunc($e->start,$e->end)->revcom->seq;
		}
		
		my $cds_s = Bio::PrimarySeq->new
		    (-seq         => $cds_str,
		     -display_id  => "$prefix:$mrna_name",
		     -description => sprintf("gene=%s %s:%s",
					     $pname,
					     $seq_id,
					     $cds->location->to_FTstring));
		$fh->{'cds'}->write_seq($cds_s);
		$fh->{'pep'}->write_seq($cds_s->translate);
	    }
	    
	    my %utrs;
	    for my $exon_top ( @exons ) 
	    {		
		my $type = lc $exon_top->primary_tag;
		for my $exon ( sort { $a->start * $strand <=> 
				      $b->start * $strand } 
			       $exon_top->location->each_Location ) {
		    if( defined $stop_codon && defined $start_codon ) {
			if( $mRNA->strand > 0 ) {
			    # 5' UTR on +1 strand
			    if( $start_codon > $exon->start ) {
				if( $start_codon > $exon->end ) {
				    # whole exon is a UTR so push it all on
				    push @{$utrs{'5utr'}},
				    Bio::SeqFeature::Slim->new
					(-seq_id => $seq_id,
					 -start  => $exon->start,
					 -end    => $exon->end,
					 -strand => $exon_top->strand,
					 -source => $source,
					 -primary=> UTR5,
					 -tag    => { 
					     'ID'     => 
						 sprintf("%s_%06d",
							 'utr5',
							 $counts->{'utr5'}++),
						 'Parent'   => $unique_mrnaid,
					     });  
				} else {
				    # push the partial exon up to the start codon
				    push @{$utrs{'5utr'}}, 
				    Bio::SeqFeature::Slim->new
					(-seq_id => $seq_id,
					 -start  => $exon->start,
					 -end    => $start_codon - 1,
					 -strand => $exon_top->strand,
					 -source => $source,
					 -primary=> UTR5,
					 -tag    => { 
					     'ID'     => 
						 sprintf("%s_%06d",
							 'utr5',
							 $counts->{'utr5'}++),
						 'Parent'   => $unique_mrnaid,
					     });
				}
			    }
			    #3' UTR on +1 strand
			    if( $stop_codon < $exon->end ) {
				if( $stop_codon < $exon->start ) {
				    # whole exon is 3' UTR
				    push @{$utrs{'3utr'}},
				    Bio::SeqFeature::Slim->new
					(-seq_id => $seq_id,
					 -start  => $exon->start,
					 -end    => $exon->end,
					 -strand => $exon_top->strand,
					 -source => $source,
					 -primary=> UTR3,
					 -tag    => { 
					     'ID'     => 
					     sprintf("%s_%06d",
						     'utr3',
						     $counts->{'utr3'}++),
						 'Parent'   => $unique_mrnaid,
					     });
				} else { 
				    # make UTR from partial exon
				    push @{$utrs{'3utr'}},
				    Bio::SeqFeature::Slim->new
					(-seq_id => $seq_id,
					 -start  => $stop_codon +1,
					 -end    => $exon->end,
					 -strand => $exon_top->strand,
					 -source => $source,
					 -primary=> UTR3,
					 -tag    => { 
					     'ID'     => 
						 sprintf("%s_%06d",
							 'utr3',
							 $counts->{'utr3'}++),
						 'Parent'   => $unique_mrnaid,
					     });
				}
			    } 
			} else {
			    # 5' UTR on -1 strand
			    if( $start_codon < $exon->end ) {
				if( $start_codon < $exon->start ) {
				    # whole exon is UTR
				    push @{$utrs{'5utr'}},
				    Bio::SeqFeature::Slim->new
					(-seq_id => $seq_id,
					 -start  => $exon->start,
					 -end    => $exon->end,
					 -strand => $exon_top->strand,
					 -source => $source,
					 -primary=> UTR5,
					 -tag    => { 
					     'ID'     => 
						 sprintf("%s_%06d",
							 'utr5',
							 $counts->{'utr5'}++),
						 'Parent'   => $unique_mrnaid,
					     });  				
				} else {
				    # push on part of exon up to the start codon 
				    push @{$utrs{'5utr'}}, 
				    Bio::SeqFeature::Slim->new
					(-seq_id => $seq_id,
					 -start   => $start_codon +1,
					 -end     => $exon->end,				     
					 -strand => $exon_top->strand,
					 -source => $source,
					 -primary=> UTR5,
					 -tag    => { 
					     'ID'     => 
						 sprintf("%s_%06d",
							 'utr5',
							 $counts->{'utr5'}++),
						 'Parent'   => $unique_mrnaid,
					     }); 
				}
			    }
			    #3' UTR on -1 strand
			    if( $stop_codon > $exon->start ) {
				if( $stop_codon > $exon->end ) {
				    # whole exon is 3' UTR
				    push @{$utrs{'3utr'}},
				    Bio::SeqFeature::Slim->new
					(-seq_id  => $seq_id,
					 -start   => $exon->start,
					 -end     => $exon->end,
					 -strand  => $exon_top->strand,
					 -source  => $source,
					 -primary => UTR3,
					 -tag     => { 
					     'ID'     => 
						 sprintf("%s_%06d",
							 'utr3',
							 $counts->{'utr3'}++),
						 'Parent'   => $unique_mrnaid,
					     }); 
				    } else { 
					# make UTR from partial exon
					push @{$utrs{'3utr'}},
					Bio::SeqFeature::Slim->new
					    (-seq_id  => $seq_id,
					     -start   => $exon->start,
					     -end     => $stop_codon - 1,				     
					     -strand  => $exon_top->strand,
					     -source  => $source,
					     -primary => UTR3,
					     -tag     => { 
						 'ID'     => 
						     sprintf("%s_%06d",
							     'utr3',
							     $counts->{'utr3'}++),
						     'Parent'   => $unique_mrnaid,
						 }); 
				    }
			    } 
			}
		    } else {
			warn("no defined stop or start codon $mrna_name\n") if $debug > 0;
		    }
		    push @newexons, Bio::SeqFeature::Slim->new
			( -seq_id => $seq_id,
			  -start  => $exon->start,
			  -end    => $exon->end,
			  -strand => $exon_top->strand,
			  -source => $source,
			  -primary=> $exon_top->primary_tag,
			  -tag    => { 
			      'ID'     => sprintf("%s%06d",
						  $type,
						  $counts->{$type}++),
			      'Parent' => $unique_mrnaid,
			  });		
		    
		}
	    }
	    
	    if( $mRNA->strand > 0 ) {
		if( exists $utrs{'5utr'} ) {
		    $fh->{'gff'}->write_feature(sort { $a->start <=> $b->start } @{$utrs{'5utr'}});
		}
	    } else {
		if( exists $utrs{'3utr'} ) {
		    $fh->{'gff'}->write_feature(sort { $a->start <=> $b->start } @{$utrs{'3utr'}});
		}
	    }
	    
	    $fh->{'gff'}->write_feature(sort { $a->start <=> $b->start } @newexons, @newcds);
	    
	    if( $mRNA->strand > 0 ) {
		if( exists $utrs{'3utr'} ) {
		    $fh->{'gff'}->write_feature(sort { $a->start <=> $b->start }
						@{$utrs{'3utr'}});
		}
	    } else {
		if( exists $utrs{'5utr'} ) {
		    $fh->{'gff'}->write_feature(sort { $a->start <=> $b->start }
						@{$utrs{'5utr'}});
		}
	    }
	}
    }
}

sub uniqlst { 
    my %x;
    return grep { ! $x{$_}++}  @_;
}

sub escape {
    
    for my $value ( @_) {
	if(  defined $value && length($value) ) { 
	    if ($value =~ /[^a-zA-Z0-9\,\;\=\.:\%\^\*\$\@\!\+\_\?\-]/) {
		$value =~ s/\t/\\t/g;       # substitute tab and newline 
		# characters
		$value =~ s/\n/\\n/g;       # to their UNIX equivalents
		
# Unescaped quotes are not allowed in GFF3
#                   $value = '"' . $value . '"';
	    }
	    $value =~ s/([\t\n\r%&\=;,])/sprintf("%%%X",ord($1))/ge;
	} 
    }
    return @_;
}
