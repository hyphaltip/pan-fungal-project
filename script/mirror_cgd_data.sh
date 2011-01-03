#!/bin/bash

# Mirror select annotations from Candida Genome Database.
# They are updated weekly, although assemblies are much less frequent.

ASSEMBLY=$1

if [ ! $ASSEMBLY ]
    then
    echo "Usage: $0 [assembly version]"
    echo "    eg: $0 A21"
    die
fi


function create_source() {
    date=$1
    touch source
    echo '' > source
    echo $date >> source
}


# There should be a master config for this.
DESTINATION_ROOT=/files/cbil/data/cbil/EuPathDB/manualDelivery/FungiDB/candida_albicans_sc5314

DATE=`date +%Y-%m-%d`

# Annotations
mkdir -p ${DESTINATION_ROOT}/genome/${ASSEMBLY}
cd ${DESTINATION_ROOT}/genome/${ASSEMBLY}

create_source "${DATE}: ${ASSEMBLY}"

CORE_ANNOTATIONS=("
    http://candidagenome.org/download/gff/C_albicans_SC5314/C_albicans_SC5314_${ASSEMBLY}_features_with_chromosome_sequences.gff.gz
    http://candidagenome.org/download/chromosomal_feature_files/C_albicans_SC5314/C_albicans_SC5314_${ASSEMBLY}_chromosomal_feature.tab
")


for URL in ${CORE_ANNOTATIONS}
do
  curl -O $URL
  echo $URL >> source
done

# Enforce some standardization.
mv C_albicans_SC5314_A21_features_with_chromosome_sequences.gff.gz candida_albicans_sc5314.gff.gz
gunzip candida_albicans_sc5314.gff.gz
mv candida_albicans_sc5314.gff candida_albicans_sc5314.gff3
curl -O http://candidagenome.org/download/gff/C_albicans_SC5314/README
curl -O http://candidagenome.org/download/chromosomal_feature_files/C_albicans_SC5314/README


# Gene ontology data
mkdir -p ${DESTINATION_ROOT}/gene_ontology/${ASSEMBLY}
cd ${DESTINATION_ROOT}/gene_ontology/${ASSEMBLY}

create_source "${DATE}: ${ASSEMBLY}"

GO_URLS=("
http://candidagenome.org/download/go/gene_association.cgd.gz
http://candidagenome.org/download/go/go_slim/goslim_candida.obo
http://candidagenome.org/download/go/go_slim/GOslim_gene_association.cgd.gz
")

for URL in ${GO_URLS}
do
  curl -O $URL
  echo $URL >> source
done  
gunzip *.gz
curl -O http://candidagenome.org/download/go/README
curl -O http://candidagenome.org/download/go/go_slim/README



# Protein domains:
mkdir -p ${DESTINATION_ROOT}/protein_domains/${ASSEMBLY}
cd ${DESTINATION_ROOT}/protein_domains/${ASSEMBLY}
curl -O http://candidagenome.org/download/domains/C_albicans_SC5314_iprscan.out
create_source "${DATE}: ${ASSEMBLY}"
echo http://candidagenome.org/download/domains/C_albicans_SC5314_iprscan.out >> source
curl -O http://candidagenome.org/download/domains/README


# Biochecmical pathways and EC numbers
mkdir -p ${DESTINATION_ROOT}/pathways/${ASSEMBLY}
cd ${DESTINATION_ROOT}/pathways/${ASSEMBLY}
curl -O http://candidagenome.org/download/pathways/calbi.tar.gz
curl -O http://candidagenome.org/download/pathways/calbibase.ocelot.gz
curl -O http://candidagenome.org/download/pathways/pathwaysAndGenes.tab
curl -O http://candidagenome.org/download/pathways/README


# Biochecmical pathways and EC numbers
mkdir -p ${DESTINATION_ROOT}/phenotypes/${ASSEMBLY}
cd ${DESTINATION_ROOT}/phentoypes/${ASSEMBLY}
curl -O http://candidagenome.org/download/phenotype/phenotype_data.tab
curl -O http://candidagenome.org/download/phenotype/README


# XREFs
# ID mappings to aliases and external databases
mkdir -p ${DESTINATION_ROOT}/xrefs/${ASSEMBLY}
cd ${DESTINATION_ROOT}/xrefs/${ASSEMBLY}
curl -O http://candidagenome.org/download/External_id_mappings/CGDID_2_GeneID.tab.gz
curl -O http://candidagenome.org/download/External_id_mappings/CGDID_2_RefSeqID.tab.gz
curl -O http://candidagenome.org/download/External_id_mappings/gp2protein.cgd.gz
curl -O http://candidagenome.org/download/External_id_mappings/README







# Do some post-processing of core genomic annotations
cd ${DESTINATION_ROOT}/genome/${ASSEMBLY}

mv C_albicans_SC5314_${ASSEMBLY}_features_with_chromosome_sequences.gff.gz candida_albicans_sc5314.gff3.gz
gunzip candida_albicans_sc5314.gff3.gz

# Uniquify
fungidb_uniquify_and_standardize_seqids.pl \
     --input  ${DESTINATION_ROOT}/genome/${ASSEMBLY}/genome/candida_albicans_sc5314.gff3 \
     --output ${DESTINATION_ROOT}/genome/${ASSEMBLY}/candida_albicans_sc5314.uniquified.gff3 \
     --prefix ${DESTINATION_ROOT}/genome/${ASSEMBLY}/CalbSC5314 \
     --ignore_contigs \
     --mapping_file ${DESTINATION_ROOT}/genome/${ASSEMBLY}/primary_gene_aliases.tab


# Split fasta from GFF
makeCustomFastaAndGffFromGff3
     --input_dir ${DESTINATION_ROOT}/genome/${ASSEMBLY}/candida_albicans_sc5314.gff3 \
     --inputFileExt gff3 \
     --output_fasta ${DESTINATION_ROOT}/genome/${ASSEMBLY}/candida_albicans_sc5314.unpacked.fasta \
     --output_gff   ${DESTINATION_ROOT}/genome/${ASSEMBLY}/candida_albicans_sc5314.unpacked.gff3


# Standard ISF pre-processing step
preprocessGFF3 
     --input_gff  ${DESTINATION_ROOT}/genome/${ASSEMBLY}/candida_albicans_sc5314.unpacked.gff3
     --output_gff ${DESTINATION_ROOT}/genome/${ASSEMBLY}/candida_albicans_sc5314.transformed.gff3

