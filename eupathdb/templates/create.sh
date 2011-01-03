#!/bin/bash

SYMBOLIC_NAME=$1
LONG_NAME=$2

WORKFLOW_ROOT=$PROJECT_HOME/ApiCommonWorkflow/Main/lib/xml/workflow/fungidb/new_template_builds
RESOURCE_ROOT=$PROJECT_HOME/ApiCommonData/Load/lib/xml/datasources/fungidb/new_template_builds



if [ ! "$LONG_NAME" ]
then
    echo "Usage: $0 SYMBOLIC_NAME FUNGIDB_DISPLAY_NAME"
    echo "    eg aspergillus_nidulans_a4 'Aspergillus nidulans (A4)'"
    exit
fi

echo "GENERATING STUB WORKFLOW FILES FOR ${SYMBOLIC_NAME}...";

echo "    creating root level workflow stanzas for ${SYMBOLIC_NAME} (paste into fungdbWorkflow.xml)..."
cp workflows/root_workflow.template ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}.root.xml



echo "    creating organism specifc workflow file..."
cp workflows/organism_workflow.template ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow.xml


echo "    creating organism-specific ISF workflow file..."
cp workflows/organism_workflow_ISF.template ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${WORKFLOW_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml

exit;

echo "GENERATING STUB RESOURCE FILES FOR A ${SYMBOLIC_NAME}";
echo "    creating organism-specific resource file..."
cp resources/organism_resource.template ${RESOURCE_ROOT}/${SYMBOLIC_NAME}.xml
perl -p -i -e "s/\[% symbolic_name %\]/${SYMBOLIC_NAME}/g" ${RESOURCE_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
perl -p -i -e "s/\[% long_name %\]/${LONG_NAME}/g" ${RESOURCE_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml
#perl -p -i -e "s/\[% species %\]/${SPECIES}/g" ${RESOURCE_ROOT}/${SYMBOLIC_NAME}_workflow_ISF.xml