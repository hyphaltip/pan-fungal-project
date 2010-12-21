#!/bin/bash

SPECIES=saccharomyces_cerevisiae_s288c
VERSION=2010-11-16

cd /files/cbil/data/cbil/EuPathDB/manualDelivery/FungiDB/${SPECIES}/genome/${VERSION}

# Uniquify
fungidb_uniquify_and_standardize_seqids.pl \
                   --input  ${SPECIES}.gff3 \
                   --output ${SPECIES}.uniquified.gff3 \
                   --prefix ScereS288C \
                   --mapping_file primary_gene_aliases.tab


# Split GFF/FASTA
makeCustomFastaAndGffFromGff3 \
                  --input_dir    ${SPECIES}.uniquified.gff3 \
                  --inputFileExt gff3 \
                  --output_fasta ${SPECIES}.unpacked.fasta \
                  --output_gff   ${SPECIES}.unpacked.gff3

# preoprocess
preprocessGFF3 --input_gff ${SPECIES}.unpacked.gff3 --output_gff ${SPECIES}.transformed.gff3


# Test FASTA load
echo "\n\nTesting FASTA load via command:\n";
cat <<EOM
ga GUS::Supported::Plugin::LoadFastaSequences  \
  --externalDatabaseName ${SPECIES}_genome_sequence_RSRC \
  --externalDatabaseVersion ${VERSION} \
  --ncbiTaxId 559292 \
  --SOTermName chromosome \
  --sequenceFile /files/cbil/data/cbil/EuPathDB/manualDelivery/FungiDB/${SPECIES}/genome/${VERSION}/${SPECIES}.unpacked.fasta \
  --regexSourceId '>(\S+)' \
  --tableName "DoTS::ExternalNASequence" \
  --regexChromosome 'Chr_(.*)'

EOM

ga GUS::Supported::Plugin::LoadFastaSequences  \
  --externalDatabaseName ${SPECIES}_genome_sequence_RSRC \
  --externalDatabaseVersion ${VERSION} \
  --ncbiTaxId 559292 \
  --SOTermName chromosome \
  --sequenceFile /files/cbil/data/cbil/EuPathDB/manualDelivery/FungiDB/${SPECIES}/genome/${VERSION}/${SPECIES}.unpacked.fasta \
  --regexSourceId '>(\S+)' \
  --tableName "DoTS::ExternalNASequence" \
  --regexChromosome 'Chr_(.*)'


# Report on qualifiers prior to reshaping
reportFeatureQualifiers --format gff3 --file_or_dir ${SPECIES}.transformed.gff3 > ${SPECIES}_feature_qualifiers.out

# Test seq feature load
echo "\n\nTesting seq feature load via command:\n";
cat <<EOM
ga GUS::Supported::Plugin::InsertSequenceFeatures \
    --extDbName ${SPECIES}_genome_annotations_RSRC \
    --extDbRlsVer ${VERSION} \
    --mapFile ${GUS_HOME}/lib/xml/isf/FungiDB/sgdGFF32Gus.xml \
    --inputFileOrDir ${SPECIES}.transformed.gff3 \
    --inputFileExtension "gff3" \
    --fileFormat gff3 \
    --soCvsVersion 1.45 \
    --defaultOrganism "Saccharomyces cerevisiae S288C" \
    --seqSoTerm "chromosome" \
    --validationLog validation.log \
    --bioperlTreeOutput bioperl.out \
    --seqIdColumn source_id \
    --naSequenceSubclass ExternalNASequence \
    --sqlVerbose 2> error.log

EOM

ga GUS::Supported::Plugin::InsertSequenceFeatures \
    --extDbName ${SPECIES}_genome_annotations_RSRC \
    --extDbRlsVer ${VERSION} \
    --mapFile ${GUS_HOME}/lib/xml/isf/FungiDB/sgdGFF32Gus.xml \
    --inputFileOrDir ${SPECIES}.transformed.gff3 \
    --inputFileExtension "gff3" \
    --fileFormat gff3 \
    --soCvsVersion 1.45 \
    --defaultOrganism "Saccharomyces cerevisiae S288C" \
    --seqSoTerm "chromosome" \
    --validationLog validation.log \
    --bioperlTreeOutput bioperl.out \
    --seqIdColumn source_id \
    --naSequenceSubclass ExternalNASequence \
    --sqlVerbose 2> error.log
