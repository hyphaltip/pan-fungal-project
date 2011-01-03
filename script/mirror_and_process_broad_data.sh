#!/bin/bash

# Mirror and preprocess broad species. Each Broad species has a unique ID like SAF2, where 2 is the assembly version.


function get_seq_and_gff() {
    species=$1
    version=$2
    code=$3
    url_base=$4
    prefix=$5

    echo "Fetching ${species}...."

    cd /files/cbil/data/cbil/EuPathDB/manualDelivery/FungiDB
    mkdir -p ${species}/genome/${version}
    cd ${species}/genome/${version}
    
# Fetch supercontigs and GTF
    curl -o ${species}_supercontigs.fasta.gz "http://www.broadinstitute.org/annotation/genome/${url_base}/download/?sp=EASupercontigsFasta&sp=${code}${version}&sp=S.gz"
    curl -o ${species}_transcripts.gtf.gz "http://www.broadinstitute.org/annotation/genome/${url_base}/download/?sp=EATranscriptsGtf&sp=${code}${version}&sp=S.gz"
    gunzip *.gz

# Convert GTF to 3-level GFF3
    ~/gusApps/FungiDB/project_home/ApiCommonData/Load/bin/fungidb_gtf2gff3_3level.pl ${species}_transcripts.gtf > ${species}_transcripts.gff3


# HANDLED BY UNIQIUFY SCRIPT
# Fix supercontigs in FASTA
    perl -p -i -e 's/supercont(\d\d\.\d{1,2}).*\n/Chromosome_$1\n/g' ${species}_supercontigs.fasta


# NOTE: for some broad species, reference sequences in fasta and GFF files do not match.
# Aspergillus nidulans
# fasta:
# >supercont1.248 of Aspergillus nidulans FGSC A4
#
# GFF:
# Contig_1.2      AN1_FINAL_CALLGENES_2   start_codon     10088   10090   .       +       0       gene_id "ANID_00005"; transcript_id "ANID_00005T0";
#
# To fix:
#    perl -p -i -e 's/supercont/Supercontig_/g' ${species}_supercontigs.fasta
#    perl -p -i -e 's/contig/supercontig/g' ${species}_supercontigs.fasta
    

# Fix supercontigs in GFF
    perl -p -i -e 's/Supercontig_/Chromosome_/g' ${species}_transcripts.gff3

# Test ISF: uniquifying sequence IDs
    fungidb_uniquify_and_standardize_seqids.pl \
	--input  ${species}_supercontigs.fasta \
	--output ${species}_supercontigs.uniquified.fasta \
	--prefix ${prefix}

# Test ISF: uniquifying transcript IDs
    fungidb_uniquify_and_standardize_seqids.pl \
	--input  ${species}_transcripts.gff3 \
	--output ${species}_transcripts.uniquified.gff3 \
	--prefix ${prefix} \
	--mapping_file primary_gene_aliases.tab

# Preprocess GFF3
    preprocessGFF3 \
	--input_gff ${species}_transcripts.uniquified.gff3 \
	--output_gff ${species}_transcripts.transformed.gff3
}


get_seq_and_gff rhizopus_oryzae_99880   3   SRO    rhizopus_oryzae RoryRA99880
exit



# species, version, code prefix, url base. In the example below, url_base is neurospora
# http://www.broadinstitute.org/annotation/genome/neurospora/download/?sp=EASupercontigsFasta&sp=SNC10&sp=S.gz
#               species                 version  Broad code    URL base             Prefix

# aspergillus group
get_seq_and_gff aspergillus_clavatus_nrrl1   1        SAC             aspergillus_group    AclaNRRL1
get_seq_and_gff aspergillus_flavus_na        2        SAFL            aspergillus_group    AflaNA
get_seq_and_gff aspergillus_fumigatus_af293  2        SAF             aspergillus_group    AfumAF293B
get_seq_and_gff aspergillus_nidulans_a4      1        SAN             aspergillus_group    AnidA4
get_seq_and_gff aspergillus_niger_na      1        SANIG           aspergillus_group    AnigNA
# Oryzae doesn't follow the pattern
#get_seq_and_gff aspergillus_oryzae_na     1        SA_oryzae_RIB40 aspergillus_group    AoryNA
get_seq_and_gff aspergillus_terreus_na    1        SAT             aspergillus_group    AterNA
get_seq_and_gff neosartorya_fischerii_na  1        SNF             aspergillus_group    NfisNA

# Neurospora
get_seq_and_gff neurospora_crassa_or74a   10        SNC             neurospora           NcraOR74A

# Coccidioides (lots more coccidioides in various states)
get_seq_and_gff coccidioides_immitis_rs      3     SCI             coccidioides_group    CimmRS
get_seq_and_gff coccidioides_immitis_h5384   1     SCIH            coccidioides_group    CimmH5384
# Doesn't follow version pattern
#get_seq_and_gff coccidioides_immitis_rmscc2394   1         SCI_RMSCC_2394  coccidioides_group    CimmRMSCC2394
#get_seq_and_gff coccidioides_immitis_rmscc3703   1         SCI_RMSCC_3703  coccidioides_group    CimmRMSCC3703
#get_seq_and_gff coccidioides_immitis_rmscc3488   1         SCI_RMSCC_3488  coccidioides_group    CimmRMSCC3488

# Cryptococcus
get_seq_and_gff cryptococcus_neoformans_grubii_h99   2         SCNA      cryptococcus_neoformans    CneoH99

# Fusarium group
get_seq_and_gff fusarium_verticillioides_na           3   SFV  fusarium_group    FverNA
get_seq_and_gff fusarium_graminearum_na               3   SFG  fusarium_group    FgraNA
get_seq_and_gff fusarium_oxysporum_lycopersici_4287   2   SFO  fusarium_group    Foxy4287

# Magnaporthe oryzae (several others in this group)
#get_seq_and_gff magnaporthe_oryzae_7015               7   SMG  magnaporthe_comparative    Mory7015
get_seq_and_gff magnaporthe_oryzae_7015               6   SMG  magnaporthe_comparative    Mory7015

# Ustilago maydis
# CONTIGS ONLY - WILL BE BROKEN; NOT DONE
# get_seq_and_gff ustilago_maydis_521                 2  SUM  ustilago_maydis    Umay

# Coprinopsis cinerea
# get_seq_and_gff coprinopsis_cinerea_okayama7130     3         SCC    coprinus_cinereus    Ccinokayama7130

# Puccinia graminis f. sp. tritici. Other species in this group available.
get_seq_and_gff puccinia_graminis_tritici_CRL75367003   2   SPG_tritici_V    puccinia_group  PgraCRL75367003


# Rhizopus oryzae
get_seq_and_gff rhizopus_oryzae_99880   3   SRO    rhizopus_oryzae RoryRA99880


# Phytophera infestans: doesn't follow pattern. skipping.
#get_seq_and_gff pyhtophera_infestans_T30   1   SP_T30-4    phytophera_infestans PinfT30





exit





