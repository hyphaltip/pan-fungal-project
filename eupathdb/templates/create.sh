#!/bin/bash

SYMBOLIC_NAME=$1
LONG_NAME=$2
#SPECIES=$3

WORKFLOW_ROOT=$PROJECT_HOME/ApiCommonWorkflow/Main/lib/xml/workflow/fungidb
RESOURCE_ROOT=$PROJECT_HOME/ApiCommonData/lib/xml/datasources/fungidb



if [ ! "$LONG_NAME" ]
then
    echo "Usage: $0 SYMBOLIC_NAME FULL_NAME"
    echo "    eg aspergillus_nidulans_a4 'Aspergillus nidulans (A4)'"
    exit
fi

echo "GENERATING STUB WORKFLOW FILES FOR A ${SYMBOLIC_NAME}\n";

echo "\tcreating root level workflow stanzas for ${SYMBOLIC_NAME} (paste into fungdbWorkflow.xml)...\n"
cp root.template ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml



echo "\tcreating organism specifc workflow file...\n"
cp organism_workflow.template ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml


echo "\tcreating organism-specific ISF workflow file...\n"
cp organism_workflow_ISF.template ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml

exit;

echo "GENERATING STUB RESOURCE FILES FOR A ${SYMBOLIC_NAME}\n";
echo "\tcreating organism-specific resource file...\n"
cp organism_resource.template ${RESOURCE_ROOT}/${SYMBOLIC_NAME}.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${RESOURCE_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${RESOURCE_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${RESOURCE_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml