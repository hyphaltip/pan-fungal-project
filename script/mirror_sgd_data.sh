#!/bin/bash

# Intended to be run as a cron.  Fetch new Saccharomyces annotations once a week.
# 0 1 * * 0 

# There should be a master config for this.
DESTINATION_ROOT=/files/cbil/data/cbil/EuPathDB/manualDelivery/FungiDB/saccharomyces_cerevisiae_s288c

DATE=`date +%Y-%m-%d`

mkdir -p ${DESTINATION_ROOT}/genome/${DATE}
cd ${DESTINATION_ROOT}/genome/${DATE}
curl -O http://downloads.yeastgenome.org/chromosomal_feature/saccharomyces_cerevisiae.gff

# Enforce some standardization.
mv saccharomyces_cerevisiae.gff saccharomyces_cerevisiae_s288c.gff3



# Gene ontology data
mkdir -p ${DESTINATION_ROOT}/gene_ontology/${DATE}
cd ${DESTINATION_ROOT}/gene_ontology/${DATE}

curl -O http://downloads.yeastgenome.org/literature_curation/go_slim_mapping.tab
curl -O http://downloads.yeastgenome.org/literature_curation/go_terms.tab
curl -O http://downloads.yeastgenome.org/literature_curation/gene_association.sgd.gz
gunzip gene_association.sgd.gz

curl -O http://downloads.yeastgenome.org/literature_curation/gene_literature.tab
curl -O http://downloads.yeastgenome.org/literature_curation/yeastcyc14.0.tar.201009.gz
gunzip yeastcyc14.0.tar.2010.09.gz


# Biochecmical pathways and EC numbers
mkdir -p ${DESTINATION_ROOT}/pathways/${DATE}
cd ${DESTINATION_ROOT}/pathways/${DATE}
curl -O http://downloads.yeastgenome.org/literature_curation/biochemical_pathways.tab


# ID mappings to aliases and external databases
mkdir -p ${DESTINATION_ROOT}/xrefs/${DATE}
cd ${DESTINATION_ROOT}/xrefs/${DATE}
curl -O http://downloads.yeastgenome.org/chromosomal_feature/SGD_features.tab
curl -O http://downloads.yeastgenome.org/chromosomal_feature/dbxref.tab
