#!/usr/bin/perl -w
# author Jason Stajich <jason_stajich@berkeley.edu>

=head1 NAME

gff2files --basedir /project/genome_files/fungi

This will write out GFF3, NT, PEP, INTRON, and CDS files where needed

See taylor_projects/scripts/jgi_gff2gff3.pl
 
=cut

use strict;
use Getopt::Long;

use Bio::SeqIO;
use Date::Manip;
use File::Spec;
use Bio::Location::Simple;
use Bio::Location::Split;
use Bio::DB::Fasta;

use constant CDSEXON => 'cds';
use constant EXON => 'exon';
use constant MRNA => 'mRNA';
use constant GENE => 'gene';

my %Seq_File = map { $_ => "$_.fasta" } qw(cds nt pep intron gene);
my $gff_ext = 'gff3';
my $gff_version = 3;

my ($transprefix,$prefix) = ( '','');

my $fix = 0; # deal with some JGI id number problems
my $write_sequence = 1;
my $src_string = "JGI";
my $informat  = 'fasta';
my $seqformat =  'fasta';
my $force = 0;
my $debug = 0;
my $basedir;
my $allversions = 0;
my $src_dir = File::Spec->catdir(qw(raw jgi));

my %uncomp = ('gz' => '/bin/zcat',
	      'Z' => '/bin/zcat',
	      'bz2' => '/usr/bin/bunzip2 -c',
	      );

GetOptions('f|force' => \$force,
	   'v|verbose|debug!' => \$debug,
	   'h|help' => sub { exec('perldoc', $0);
               exit(0);
           },
	   'all|allversions' => \$allversions,
	   'b|basedir:s'     => \$basedir,
	   "w|s|write|seq!" => \$write_sequence,
	   );
die("need a basedir") unless $basedir && -d $basedir;

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
	my $prefix = substr($genus,0,1).substr($spp,0,3). "_$strain";
	# skip files
	next if ! -d File::Spec->catfile($sppath,$strain); 
	warn(" ---> $strain\n") if $debug;

	# gotta have a proper raw/jgi directory to proceed
	my $jgipath = File::Spec->catfile($sppath,$strain,$src_dir);
	unless( -d $jgipath ) {
	    warn("cannot file $src_dir in the directory $jgipath\n") if $debug;
	    next SP;
	}
	opendir(VERSIONS, $jgipath) || die "$jgipath: $!";
	my @versions;
	for my $ver ( readdir(VERSIONS) ) {
	    next if $ver =~ /^\./;
	    next unless -d File::Spec->catfile($jgipath,$ver);
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
		my $full_version = File::Spec->catfile($jgipath,$version);
		opendir(VER, $full_version) || die $!;

		while( my ($filetype,$filename) = each %files ) {
		    $fh{$filetype} = Bio::SeqIO->new(-format => $seqformat,
						     -file   => ">$filename");
		}
		my $gff_fh;
		open($gff_fh,sprintf(">%s/%s_%s.%s.%s",
					File::Spec->catfile($sppath,$strain),
					$species,
					$strain,
					$version,
					$gff_ext));
		print $gff_fh "##gff-version 3\n","##date-created ".localtime(),"\n";
		    
		my %features;
		my @seqs;
		my %seqids;
		my @files = readdir(VER);
		for my $file ( @files ) {
		    next unless ($file =~ /(\S+)\.(?:nt|fasta|fa)(?:\.(bz2|gz|Z))?/);
		    my ($stem,$ext) = ( $1,$2 );
		    
		    my $full_path = File::Spec->catfile($full_version,$file);
		    my $fh;
		    
		    if( $ext ) {
			open($fh, "$uncomp{$ext} $full_path |") || 
			    die "$full_path: $!";
		    } else {
			open($fh, "< $full_path") || die "$full_path: $!";
		    }

		    my %features;
		    my $seqio = Bio::SeqIO->new(-format => $informat,
						-fh     => $fh);
		    while( my $seq = $seqio->next_seq ) {
			my $seqid = $seq->display_id;
			my $id;
			if( $seqid =~ /(scaffold_\d+)/ ) {
			    $id = sprintf("%s_%s",$prefix,$1);
			} elsif( $seqid =~ /^chr/ ) {
			    $id = sprintf("%s_%s", $prefix,$seqid);
			} else {
			    warn("cannot fix ID for seqid: $seqid ($file)\n");
			    next;
			}
			$seqids{$id} = $seq->length;
			$seq->display_id($id);
			$seq->description("");
			
			if( $write_sequence) {		
			    print $gff_fh join("\t", $seq->display_id,
					       'chromosome',
					       'scaffold',
					       1, $seq->length,
					       '.', '+','.', sprintf("ID=%s;Name=%s",
								     $seq->display_id,$seq->display_id)),"\n";
			}
			$fh{'nt'}->write_seq($seq);
		    }
		}
		$fh{'nt'}->close;
		my $dbh = Bio::DB::Fasta->new($files{'nt'});
		for my $file ( @files ) {
		    next unless $file =~ /(\S+)\.(?:gff|gtf|gff3)(?:\.(bz2|gz|Z))?/;
		    my ($stem,$extension) = ( $1,$2);
		    my $full_path = File::Spec->catfile($full_version,$file);
		    my ($out,$in);
		    if( $extension ) {
			open($in, "$uncomp{$extension} $full_path |") || 
			    die "$full_path: $!";
		    } else {
			open($in, "< $full_path") || die "$full_path: $!";
		    }

		    my %genes;
		    my %genes2alias;
		    my %transcript2name;
		    my %gene2name;
		    my %transcript2protein;
		    my $last_tid;
		    while(<$in>) {
			chomp;
			my $line = $_;
			my @line = split(/\t/,$_);
			my ($seqid,$src,$type,$start,$end,$score,$strand,$frame,$lastcol) = @line;
			    
			next unless ($type eq 'CDS'  || $type eq 'exon' || 
				     $type eq 'stop_codon');			
			my $id;
			if( $seqid =~ /(scaffold_\d+)/ ) {
			    $id = sprintf("%s_%s",$prefix,$1);
			} elsif( $line[0] =~ /^chr/ ) {
			    $id  = sprintf("%s_%s", $prefix,$seqid);
			} else {
			    warn("cannot match contig out of $seqid\n");
			    close($in);
			    next;
			}
			$seqid = $id;
			if( ! defined $seqids{$seqid} ) {
			    warn("no sequence for $seqid\n");
			    exit;
			} elsif ( $seqids{$seqid} < $end ) {
			    warn("seq length of $seqid is $seqids{$seqid} is less than annotation end ($end)\n");
			    exit;
			}
			$line[0] = $seqid;

			$line[-1] =~ s/^\s+//;
			$line[-1] =~ s/\s+$//;
			my %set = map { split(/\s+/,$_,2) } split(/\s*;\s*/,pop @line);;
			
			if( exists $set{'transcriptId'} ) {
			    $set{'transcript_id'} = $set{'transcriptId'};
			    delete $set{'transcriptId'};
			}
			if( exists $set{'featureId'} ) {
			    $set{'transcript_id'} = $set{'transcriptId'};
			    delete $set{'featureId'};
			}
			if( exists $set{'name'} ) {
			    $set{'gene_name'} = $set{'name'};
			    delete $set{'name'};
			}
			my ($gid,$tid,$pid,$tname,$gname,$alias) = 
			    ( map { $set{$_} }
			      qw(gene_id transcript_id protein_id
				 transcript_name gene_name aliases));
			for ( $gid,$tid,$pid,$tname,$gname,$alias ) {
			    s/\"//g if defined $_;
			}
			if( ! $tid ) {
			    $tid = $last_tid;
			}    
			if( defined $tid && $tid =~ /^\d+$/ ) {	# JGI transcript ids are numbers only
			    $tid = "t_$tid";
			}
			if( $tname ) {
			    $transcript2name{$tid} = $tname;
			}
			$gid = $gname || $tid unless defined $gid;
			if( ! $gid || ! $tid) {
			    warn(join(" ", keys %set), "\n");
			    die "Not GID or TID invalid GTF: $line \n";
			}
			if( $pid ) {
			    $transcript2protein{$tid} = $pid;
			}
#    warn("tid=$tid pid=$pid gid=$gid tname=$tname gname=$gname\n");
			if( $fix ) {
			    if( $tid =~ /(\S+)\.\d+$/) {
				$gid = $1;
			    }
			}
			if( $gname) {
			    $gene2name{$gid} = $gname;
			}
		    
			if( ! defined $genes{$gid}->{min} ||
			    $genes{$gid}->{min} > $line[3] ) {
			    $genes{$gid}->{min} = $line[3];
			}
			if( ! defined $genes{$gid}->{max} ||
			    $genes{$gid}->{max} < $line[4] ) {
			    $genes{$gid}->{max} = $line[4];
			}
			if( ! defined $genes{$gid}->{strand} ) {
			    $genes{$gid}->{strand} = $line[6];
			}
			if( ! defined $genes{$gid}->{chrom} ) {
			    $genes{$gid}->{chrom} = $line[0];
			}
			if( ! defined $genes{$gid}->{src} ) {
			    $genes{$gid}->{src} = $line[1];
			}
			if( defined $alias ) {
			    $genes2alias{$gid} = join(',',split(/\s+/,$alias));
			}
			push @{$genes{$gid}->{transcripts}->{$tid}}, [@line];
			$last_tid = $tid;    
		    }
		    my %counts;
		    for my $gid ( sort { $genes{$a}->{chrom} cmp $genes{$b}->{chrom} ||
					 $genes{$a}->{min} <=> $genes{$b}->{min}
				     } keys %genes ) {
			my $gene = $genes{$gid};
			my $gene_id = sprintf("%sgene%06d",$prefix,$counts{'gene'}++);
			my $aliases = $genes2alias{$gid};
			my $gname   = $gene2name{$gid};
			if( $gname ) {
			    if( $aliases ) {
				$aliases = join(",",$gid,$aliases);	
			    } else {
				$aliases = $gid;
			    }
			} else {
			    $gname = $gid;
			}
			$gname = sprintf('"%s"',$gname) if $gname =~ /[;\s,]/;
			my $ninth  = sprintf("ID=%s;Name=%s",$gene_id, $gname);
			if( $aliases && $aliases ne $gname ) {
			    $ninth .= sprintf(";Alias=%s",$aliases);
			}
			
			print $gff_fh join("\t", ( $gene->{chrom}, 
						   $gene->{src},
						   'gene',
						   $gene->{min},
						   $gene->{max},
						   '.',
						   $gene->{strand},
						   '.',
						   $ninth)),"\n";
			while( my ($transcript,$exons) = each %{$gene->{'transcripts'}} ) {
			    my $mrna_id = sprintf("%smRNA%06d",$prefix,$counts{'mRNA'}++);
			    my @exons = grep { $_->[2] eq 'exon' } @$exons;
			    my @cds   = grep { $_->[2] eq 'CDS'  } @$exons;	
			    my @stop_codons   = grep { $_->[2] eq 'stop_codon'  } @$exons;

			    if( ! @exons ) {
				@exons = @cds;
				for my $e ( @cds ) {
				    push @exons, [@$e];
				    $exons[-1]->[2] = 'exon';
				}
			    }
			    my $proteinid = $transcript2protein{$transcript};
			    my ($chrom,$src,$strand,$min,$max);
			    for my $exon ( @exons ) {
				$chrom = $exon->[0] unless defined $chrom;
				$src   = $exon->[1] unless defined $src;
				$min   = $exon->[3] if( ! defined $min || $min > $exon->[3]);
				$max   = $exon->[4] if( ! defined $max || $max < $exon->[4]);
				$strand = $exon->[6] unless defined $strand;	
			    }

			    my $strand_val = $strand eq '-' ? -1 : 1;
			    my $transname = $transprefix.$transcript;
			    my $transaliases = $transcript;
			    if( exists $transcript2name{$transcript} ) {
				$transname = $transcript2name{$transcript};
				$transname = sprintf('"%s"',$transname) if $transname =~ /[;\s,]/;
			    }
			    my $mrna_ninth = sprintf("ID=%s;Parent=%s;Name=%s",
						     $mrna_id,$gene_id,$transname);
			    if( $transaliases && $transaliases ne $transname ) {
				$mrna_ninth .= sprintf(";Alias=%s",$transaliases);
			    }
			    print $gff_fh join("\t",($chrom,
						     $src,
						     'mRNA',
						     $min,
						     $max,
						     '.',
						     $strand,
						     '.',
						     $mrna_ninth,
						     )),"\n";
			    my $mrnaLoc = Bio::Location::Simple->new(-start => $min,
								     -end   => $max,
								     -strand=> $strand_val);
			    $fh{'gene'}->write_seq(Bio::PrimarySeq->new(-seq => $dbh->seq($chrom,$strand_val > 0 ? ($min =>$max) : ($max => $min)),
									-display_id => "%s:%s",$prefix,$transname,
									-description => sprintf("gene=%s %s:%s",
												$gid,
												$chrom,
												$mrnaLoc->to_FTstring)));
									
			    my ($start_codon,$stop_codon);
			    # order 5' -> 3' by multiplying start by strand
			    
			    @cds = sort { $a->[3] * $strand_val <=> 
					  $b->[3] * $strand_val } @cds;			    
			    
# This was old checking code to deal with making sure CDSes ended with a stop codon
# it seems that the data is okay?  
# Based on Phycomyces gene as an exemplar with problems: fgeneshPB_pg.92__8
# 			    if( @stop_codons ) {
# 				if(overlaps([$stop_codons[0]->[3],
# 					     $stop_codons[0]->[4] ],
# 					    [$cds[-1]->[3],$cds[-1]->[4]]) ) {
				    
# 				    if( $strand_val > 0 ) {		
# 					#warn("stop codon is ", join("\t", @{$stop_codons[0]}), "\n"); 				    
# 					$cds[-1]->[4] = $stop_codons[0]->[4];
# 				    } else {
# 					#warn("stop codon is ", join("\t", @{$stop_codons[0]}), "\n");
					
# 					$cds[-1]->[3] = $stop_codons[0]->[3];
# 				    }
# 				} else {
# 				    # stop_codon doesn't overlap last CDS
# 				    # going to skip it
# 				    warn(sprintf("stop codon %d..%d doesn't overlap last CDS %d..%d for %s\n",
# 						 $stop_codons[0]->[3],
# 						 $stop_codons[0]->[4],
# 						 $cds[-1]->[3],
# 						 $cds[-1]->[4],
# 						 $transname)) if $debug > 0;
# 				}
# 			    }
			    my ($cds_str,$icount,$last_cds);			    
			    my $loc = Bio::Location::Split->new;
			    for my $cds ( @cds ) {
				unless( defined $start_codon ) {
				    $start_codon = ( $strand_val > 0) ? $cds->[3] : $cds->[4];
				}
				
				# last writer wins so keep running this through
				# rather than worrying about grabbing last CDS after
				# this is through
				$stop_codon = ($strand_val > 0) ? $cds->[4] : $cds->[3];
				my $exon_ninth = sprintf("ID=%s_cds%06d;Parent=%s",
							 $prefix,
							 $counts{'CDS'}++,
							 $mrna_id);
				if( $proteinid ) {
				    $proteinid = sprintf('"%s"',$proteinid) if $proteinid =~ /[;\s,]/;
				    $exon_ninth .= sprintf(";Name=%s",$proteinid);
				} 
				#if( ($cds->[3] - $cds->[4]) != 0 ) {
				# skip zero length introns from brain-dead JGI output
				my ($t_s,$t_e) = sort { $a <=> $b } ($cds->[3],$cds->[4]);
				if( $strand_val > 0 ) {
				    $cds_str .= $dbh->seq($cds->[0], $t_s => $t_e);
				} else {
				    if( ($t_e - $t_s) == 0 ) {
					# 1 length features have wrong rev-comp because Bio::DB::Fasta will always return them on +1 strand
					$cds_str .= Bio::PrimarySeq->new(-seq => $dbh->seq($cds->[0], $t_e => $t_s))->revcom->seq;
				    } else {
					$cds_str .= $dbh->seq($cds->[0], $t_e => $t_s);
				    }
				}
				if( ! $cds_str ) {
				    die("cannot get seq for ",$cds->[0],":", $cds->[3],"..", $cds->[4]);
				}
				
				$loc->add_sub_Location(Bio::Location::Simple->new(-start => $t_s,
										  -end   => $t_e,
										  -strand=> $strand_val));
				
				if( $last_cds ) {
				    my $intronloc = Bio::Location::Simple->new(-strand => $strand_val);
				    if( $strand_val > 0 ) {
					$intronloc->start($last_cds->[1] + 1); #last_cds->[1] is stop
					$intronloc->end( $cds->[3] - 1);
				    } else {
					$intronloc->start($cds->[4] + 1);
					$intronloc->end( $last_cds->[0] - 1); #last_cds->[0] is start
				    }
				    if( $intronloc->start > $intronloc->end ) {
					my $lst = $intronloc->start;
					$intronloc->start($intronloc->end);
					$intronloc->end($lst);
				    }
				    if( $intronloc->length > 3) { # ignore possible frame-shift introns
					my $intron_str =  
					    $dbh->seq($cds->[0], ( $intronloc->strand > 0 ? 
								   ($intronloc->start => $intronloc->end) : 
								   ($intronloc->end => $intronloc->start))
						      );

					my $intron_s = Bio::PrimarySeq->new
					    (-display_id => sprintf("%s:%s.i%s",$prefix,$transname,$icount++),
					     -seq => $intron_str,
					     -description=> sprintf("gene=%s %s:%s",
								    $gid,
								    $chrom,
								    $intronloc->to_FTstring));
					$fh{'intron'}->write_seq($intron_s);
				    }
				}
				$last_cds = [sort { $a <=> $b } $cds->[3], $cds->[4]];			    
				$cds = [$cds->[3], join("\t", @$cds, $exon_ninth)];
			    }
			    my $cds_s = Bio::PrimarySeq->new
				(-seq         => $cds_str,
				 -display_id  => "$prefix:$transname",
				 -description => sprintf("gene=%s %s:%s",
							 $gid,
							 $chrom,
							 $loc->to_FTstring));
			    $fh{'cds'}->write_seq($cds_s);
			    my $pepseq = $cds_s->translate;
			    if( $pepseq->seq =~ /\*\w+/ ){
				warn($transname, " $gid ", $strand_val, "\n");
			    }
			    if( defined $proteinid ) {
				$pepseq->description(sprintf("protein_id=%d %s",$proteinid,$pepseq->description));
			    }
			    $fh{'pep'}->write_seq($pepseq);
								       
			    my %utrs;
			    for my $exon ( sort { $a->[3] * $strand_val <=> 
						      $b->[3] * $strand_val } 
					   @exons ) {
				# how many levels deep can you think?
				if( defined $stop_codon && defined $start_codon ) {
				    if( $strand_val > 0 ) {
					# 5' UTR on +1 strand
					if( $start_codon > $exon->[3] ) {
					    if( $start_codon > $exon->[4] ) {
						# whole exon is a UTR so push it all on
						push @{$utrs{'5utr'}},
						[ $exon->[3],
						  join("\t",
						       ( $exon->[0],
							 $exon->[1],
							 'five_prime_utr',
							 $exon->[3],
							 $exon->[4],
							 '.',
							 $strand,
							 '.',
							 sprintf("ID=%s_utr5%06d;Parent=%s",
								 $prefix,
								 $counts{'5utr'}++,
								 $mrna_id)))];
					    } else {
						# push the partial exon up to the start codon
						push @{$utrs{'5utr'}}, 
						[ $exon->[3],
						  join("\t",
						       $exon->[0],
						       $exon->[1],
						       'five_prime_utr',
						       $exon->[3],
						       $start_codon - 1,
						       '.',
						       $strand,
						       '.',
						       sprintf("ID=%s_utr5%06d;Parent=%s",
							       $prefix,
							       $counts{'5utr'}++,
							       $mrna_id)
						       )];
					    }
					}
					#3' UTR on +1 strand
					if( $stop_codon < $exon->[4] ) {
					    if( $stop_codon < $exon->[3] ) {
						# whole exon is 3' UTR
						push @{$utrs{'3utr'}},
						[ $exon->[3],
						  join("\t",
						       ( $exon->[0],
							 $exon->[1],
							 'three_prime_utr',
							 $exon->[3],
							 $exon->[4],
							 '.',
							 $strand,
							 '.',
							 sprintf("ID=%s_utr3%06d;Parent=%s",
								 $prefix,
								 $counts{'3utr'}++,
								 $mrna_id)))];
					    } else { 
						# make UTR from partial exon
						push @{$utrs{'3utr'}},
						[ $exon->[3],
						  join("\t",
						       ( $exon->[0],
							 $exon->[1],
							 'three_prime_utr',
							 $stop_codon +1,
							 $exon->[4],
							 '.',
							 $strand,
							 '.',
							 sprintf("ID=%s_utr3%06d;Parent=%s",
								 $prefix,
								 $counts{'3utr'}++,
								 $mrna_id)))];
					    }
					} 
				    } else {
					# 5' UTR on -1 strand
					if( $start_codon < $exon->[4] ) {
					    if( $start_codon < $exon->[3] ) {
						# whole exon is UTR
						push @{$utrs{'5utr'}},
						[ $exon->[3],
						  join("\t",
						       $exon->[0],
						       $exon->[1],
						       'five_prime_utr',
						       $exon->[3],
						       $exon->[4],
						       '.',
						       $strand,
						       '.',
						       sprintf("ID=%s_utr5%06d;Parent=%s",
							       $prefix,
							       $counts{'5utr'}++,
							       $mrna_id)) ];
					    } else {
						# push on part of exon up to the start codon 
						push @{$utrs{'5utr'}}, 
						[ $exon->[3], 
						  join("\t",$exon->[0],
						       $exon->[1],
						       'five_prime_utr',
						       $start_codon + 1,
						       $exon->[4],
						       '.',
						       $strand,
						       '.',
						       sprintf("ID=%s_utr5%06d;Parent=%s",
							       $prefix,
							       $counts{'5utr'}++,
							       $mrna_id))];
					    }
					}		
					#3' UTR on -1 strand
					if( $stop_codon > $exon->[3] ) {
					    if( $stop_codon > $exon->[4] ) {
						# whole exon is 3' UTR
						push @{$utrs{'3utr'}},
						[ $exon->[3],
						  join("\t",
						       ( $exon->[0],
							 $exon->[1],
							 'three_prime_utr',
							 $exon->[3],
							 $exon->[4],
							 '.',
							 $strand,
							 '.',
							 sprintf("ID=%s_utr3%06d;Parent=%s",
								 $prefix,
								 $counts{'3utr'}++,
								 $mrna_id)))];
					    } else { 
						# make UTR from partial exon
						push @{$utrs{'3utr'}},
						[ $exon->[3],
						  join("\t",
						       ( $exon->[0],
							 $exon->[1],
							 'three_prime_utr',
							 $exon->[3],
							 $stop_codon -1,
							 '.',
							 $strand,
							 '.',
							 sprintf("ID=%s_utr3%06d;Parent=%s",
								 $prefix,
								 $counts{'3utr'}++,
								 $mrna_id)))];
					    }
					} 
				    }
				}
				$exon = [$exon->[3],
					 join("\t", @$exon, sprintf("ID=%s_exon%06d;Parent=%s",
								    $prefix,
								    $counts{'exon'}++,
								    $mrna_id))];
			    }
			    if( $strand_val > 0 ) {
				if( exists $utrs{'5utr'} ) {

				    print $gff_fh join("\n", map { $_->[1] } sort { $a->[0] <=> $b->[0] }
					       @{$utrs{'5utr'}}), "\n";
				}
			    } else {
				if( exists $utrs{'3utr'} ) {
				    print $gff_fh join("\n", map { $_->[1] } sort { $a->[0] <=> $b->[0] }
					       @{$utrs{'3utr'}}), "\n";
				}
			    }

			    print $gff_fh join("\n", ( map { $_->[1] } sort { $a->[0] <=> $b->[0] }
						       @exons, @cds)), "\n";
			    if( $strand_val > 0 ) {
				if( exists $utrs{'3utr'} ) {
				    print $gff_fh join("\n", map { $_->[1] } sort { $a->[0] <=> $b->[0] }
						       @{$utrs{'3utr'}}), "\n";
				}
			    } else {
				if( exists $utrs{'5utr'} ) {
				    print $gff_fh join("\n", map { $_->[1] } sort { $a->[0] <=> $b->[0] }
					       @{$utrs{'5utr'}}), "\n";
				}
			    }
			}
		    }
		}
		unlink($files{'nt'}.".index");
	    }
	    last unless $allversions;
	}
	last if $debug > 1;
    }
    closedir(S);
    last if $debug > 1;
}

sub overlaps {
    my ($left,$right) = @_;
    my ($left_s,$left_e) = sort { $a <=> $b } @$left;
    my ($right_s,$right_e) = sort { $a <=> $b } @$right;
    return ! ( $left_s > $right_e ||
	       $left_e < $right_s);
}
