#!/usr/bin/perl -w

# This script converts JGI jff into ISF compatible format
# Takes 2 arguments, 1. Is the gff file 2. Is the gene prefix
# Example: perl JGIToISFGFF.pl <filename> <Physo_> > output
# Author: Sucheta
 

my %HOH = &readJGIgff($ARGV[0]);
my %geneHash;

my $exon_num;
my $cds_num;
my $prefix=$ARGV[1];

for my $scaffold (keys %HOH) {
	
  for my $gene (keys %{$HOH{$scaffold}}) {
		
    $exon_num=1;
    $cds_num=1;
    my (@start, @stop, @exon, @CDS);

    # shouldn't these be sorted by strand and position?
    if (exists $HOH{$scaffold}{$gene}{'start_codon'}) {
			
      @start = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'start_codon'}};
    }
    if (exists $HOH{$scaffold}{$gene}{'stop_codon'}) {
		
      @stop = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'stop_codon'}};
    }
    if (exists $HOH{$scaffold}{$gene}{'exon'}) {
		
      @exon = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'exon'}};
    }
    if (exists $HOH{$scaffold}{$gene}{'CDS'}) {
		
      @CDS = sort{$a <=> $b} @{ $HOH{$scaffold}{$gene}{'CDS'}};
    }
		

    my $geneName = $HOH{$scaffold}{$gene}{'geneid'};

    print join("\t",$scaffold,'JGI','gene',$exon[0],$exon[-1],'.',
	       $HOH{$scaffold}{$gene}{'strand'},'.',"ID \"$prefix$geneName\";"),"\n";

# the rest of this needs to be fixed		
    print "$scaffold\tVBI\tmRNA\t$exon[0]\t$exon[-1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"$prefix$geneName"."T0\"; Parent \"$prefix$geneName\";\n";
    if ($start[0]) {
		
      print "$scaffold\tVBI\tstart_codon\t$start[0]\t$start[1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"start_$geneName.1\"; Parent \"$prefix$geneName"."T0\";\n";
    }

    for (my $i=0;$i<$#exon;$i+=2) {

				
      print "$scaffold\tVBI\texon\t$exon[$i]\t$exon[$i+1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"$prefix$geneName.$exon_num:exon\"; Parent \"$prefix$geneName"."T0\";\n";
			
			
      if ($CDS[$i]) {	
				
	print "$scaffold\tVBI\tCDS\t$CDS[$i]\t$CDS[$i+1]\t.\t$HOH{$scaffold}{$gene}{'strand'}\t.\tID \"$prefix$geneName.$cds_num:CDS\"; Parent \"$prefix$geneName"."T0\";\n";
	$cds_num++;

      }
      $exon_num++;

    }
		
    if ($stop[0]) {
		
      print join("\t",$scaffold,'JGI','stop_codon',$stop[0],$stop[1],'.',$HOH{$scaffold}{$gene}{'strand'},'.',
		 sprintf('ID "stop_%s.1"; Parent "%s%s.T0"',$geneName,$prefix,$geneName)),"\n";
    }

  }


}	
			

sub readJGIgff {

  my $fileName = shift;
  my %HOH;
  my %geneNameHash;

  open PRED, $fileName or die "Can't open file $!\n";

  while (<PRED>) {
    my ($gene_id,$name);
    if (/name\s+\"(\S+)\";\s+transcriptId\s+(\d+)/) {
      $name    = $1;
      $gene_id = $2;
      $geneNameHash{$name} = $gene_id;
    }
  }

  seek(PRED,0,0);

  while (<PRED>) {
    next if /^\#/;
    chomp;
	
		
    my @line = split(/\t/,$_);
    my $last = scalar(@line) - 1;
    my $name;

    #print "line last is $line[$last]\n";
    # can't you just use -1 here? and use s// to do this in one replacement?
    if ($line[$last] =~ /name\s+\"(\S+)\"/) {
      $name = $1;
      $line[$last] = $name;
    }
			
    # array references here???
    # don't do it with patterns, parse the line
    if ($_ =~ /start_codon/i) {

      push(@{$HOH{$line[0]}->{$line[$last]}->{'start_codon'}}, $line[3], $line[4]);
    } elsif ($_ =~ /stop_codon/i) {
      push(@{$HOH{$line[0]}->{$line[$last]}->{'stop_codon'}}, $line[3], $line[4]);
    } elsif ($_ =~/CDS/i) {

      push(@{$HOH{$line[0]}->{$line[$last]}->{'CDS'}}, $line[3], $line[4]);
    } elsif ($_ =~/exon/i) {

      push(@{$HOH{$line[0]}->{$line[$last]}->{'exon'}}, $line[3], $line[4]);
    }
		
    $HOH{$line[0]}->{$line[$last]}->{'strand'} = $line[6];

    $HOH{$line[0]}->{$line[$last]}->{'score'} = $line[5];
		
    $HOH{$line[0]}->{$line[$last]}->{'geneid'} = $geneNameHash{$name};
  }

  close PRED;
  return %HOH;
}
