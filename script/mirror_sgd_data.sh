#!/bin/bash

# Intended to be run as a cron.  Fetch new Saccharomyces annotations once a week.
# 0 1 * * 0 

# There should be a master config for this.
DESTINATION_ROOT=/files/cbil/data/cbil/EuPathDB/manualDelivery/FungiDB/saccharomyces_cerevisiae_s288c
CHROMOSOMES=${DESTINATION_ROOT}/genome

DATE=`date +%Y-%m-%d`
echo ${CHROMOSOMES}/${DATE}
mkdir -p ${CHROMOSOMES}/${DATE}
cd ${CHROMOSOMES}/${DATE}
curl -O http://downloads.yeastgenome.org/chromosomal_feature/saccharomyces_cerevisiae.gff

# Enforce some standardization.
mv saccharomyces_cerevisiae.gff saccharomyces_cerevisiae_s288c.gff3
