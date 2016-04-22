#!/usr/bin/perl -w
use strict;
use Bio::DB::GenBank;
use Bio::DB::Query::GenBank;
use File::Path;
use Getopt::Long;

my $DEBUG = 0;
my $basedir = '/tmp/genbank_staging';
GetOptions(
	   'd|debug' => \$DEBUG,
	   'b|basedir:s' => \$basedir);


my $ncbi_id_file = shift || '/home/stajich/projects/genome_files_src/data_files/fungal_genbank_accessions.dat';
my $gb = Bio::DB::GenBank->new(-verbose => $DEBUG);

open(QUERY, $ncbi_id_file) || die $!;

while(<QUERY>) {
    next if /^\#/ || /^\s+$/;
    chomp;
    my ($species,$accessions) = split(/\t/,$_);
    my (@not,@qstring,$keep);
    for my $pair ( split(/,/,$accessions) ) {
	my ($start,$finish) = split(/-/,$pair);
	my ($s_letter,$s_number, $f_letter,$f_number);
	my $nl;
	if( $start =~ /^([A-Za-z_]+)(\d+)/ ) {
	    $nl = length($2);
	    ($s_letter,$s_number) = ($1,$2);
	} else {
	    warn("Cannot process accession pair $pair\n");
	    next;
	}
	if( $finish ) {
	    if( $finish =~ /^([A-Za-z_]+)(\d+)/ ) {	    
		($f_letter,$f_number) = ($1,$2);
	    }  else {
		warn("Cannot process accession pair $pair\n");
		next;
	    }
	    if( $f_letter ne $s_letter ) {
		warn("Accession set does not match in $pair ($f_letter, $s_letter)\n");
		next;
	    }
	    push @qstring, sprintf("%s:%s[ACCN]",$start,$finish);
	    for(my $i = $s_number; $i <= $f_number; $i++) {
		my $acc = sprintf("%s%0".$nl."d",$s_letter,$i);
		if( -f File::Spec->catfile($basedir,$species,"$acc.gbk.gz")) {
		    push @not, sprintf("NOT %s",$acc);
		} else {
		    $keep++;
		}
	    }

	} else {
	    next if -f File::Spec->catfile($basedir,$species,"$start.gbk.gz");
	    push @qstring, sprintf("%s",$start);
	    $keep++;
	}
    }
    next unless (@qstring && $keep);
    my $qstring = join(" OR ", @qstring) . " " . join(" ",@not);
    warn("qstring is $qstring\n") if $DEBUG;
    my $query = Bio::DB::Query::GenBank->new(-db=>'nucleotide',
					     -verbose => $DEBUG,
					     -query=>$qstring,
					     );
    my $stream = $gb->get_Stream_by_query($query);

    my $targetdir = File::Spec->catfile($basedir,$species);
    mkpath($targetdir);
#    for my $add ( $species, qw(raw ncbi), $version ) {
#	$targetdir = File::Spec->catfile($targetdir,$add);
#	mkdir($targetdir);
#    }
    while (my $seq = $stream->next_seq) {
	# do something with the sequence object
	my $acc = $seq->accession_number;
	warn("$targetdir/$acc.gbk.gz\n") if $DEBUG;
	my $out = Bio::SeqIO->new(-format => 'genbank',
				  -file   => "|gzip -c > $targetdir/$acc.gbk.gz");
	$out->write_seq($seq);
    }
    last if $DEBUG;
}
