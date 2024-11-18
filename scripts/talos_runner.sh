#!/usr/bin/env bash

set -ex

# Accept as an argument the dataset id, default to "example"
DATASET_ID=${1:-example}
DATASET_DIR=$DATA_DIR/$DATASET_ID

# Set the path to use for an output directory.
OUTPUT_DIR="${DATASET_DIR}/talos_$(date +%F)"
mkdir -p $OUTPUT_DIR

# Pass the config TOML file, and export as an environment variable as required by talos.
CONFIG_FILE="/scripts/config.toml"
export TALOS_CONFIG="$CONFIG_FILE"

# Pass the Pedigree and optional phenopackets files to the script
# Assume these are named as below.
# Find all .ped files in the dataset directory
PED_FILES=($DATASET_DIR/*.ped)

# Find all .json files in the dataset directory
JSON_FILES=($DATASET_DIR/*.json)

# Check the number of .ped files found
if [ ${#PED_FILES[@]} -eq 0 ] || [ "${PED_FILES[0]}" == "$DATASET_DIR/*.ped" ]; then
    echo "No .ped files found in $DATASET_DIR."
    PED_ERROR=1
elif [ ${#PED_FILES[@]} -gt 1 ]; then
    echo "Multiple .ped files found in $DATASET_DIR."
    PED_ERROR=1
else
    PED_FILE=${PED_FILES[0]}
fi

# Check the number of .json files found
if [ ${#JSON_FILES[@]} -eq 0 ] || [ "${JSON_FILES[0]}" == "$DATASET_DIR/*.json" ]; then
    echo "No .json files found in $DATASET_DIR. Not performing phenotype analysis."
    # Don't set PHENOPACKET_FILE
elif [ ${#JSON_FILES[@]} -gt 1 ]; then
    echo "Multiple .json files found in $DATASET_DIR."
    JSON_ERROR=1
else
    PHENOPACKET_FILE=${JSON_FILES[0]}
fi

# TODO handle optional phenopacket file once Talos supports it better.

# Exit if there were errors with either .ped or .json files
if [ -n "$PED_ERROR" ] || [ -n "$JSON_ERROR" ]; then
    echo "Errors found with input files. Exiting."
    exit 1
fi

# Pass the annotated VCF to the script.
SMALL_VARIANT_INPUT_VCF="${DATASET_DIR}/vep/annotated.vcf.bgz"

# Pass the reference data to the script.
CLINVAR_DECISIONS="${REF_DIR}/talos/clinvarbitration/24-11/clinvar_decisions.ht"
CLINVAR_PM5="${REF_DIR}/talos/clinvarbitration/24-11/clinvar_pm5.ht"
HPO_OBO="${REF_DIR}/talos/HPO.obo"
GEN2PHEN="${REF_DIR}/talos/genes_to_phenotype.txt"
PHENIO_DB="${REF_DIR}/talos/phenio.db"

### Run individual Talos modules.

# Identify the PanelApp data to use.
MATCHED_PANELS="${OUTPUT_DIR}/matched_panels.json"
GeneratePanelData \
  --input "$PHENOPACKET_FILE" \
  --output "$MATCHED_PANELS" \
  --hpo "$HPO_OBO"

# Query PanelApp for panels
PANELAPP_RESULTS="${OUTPUT_DIR}/panelapp_results.json"
QueryPanelapp \
  --input "$MATCHED_PANELS" \
  --output "$PANELAPP_RESULTS"

# Convert the input VCF to a Hail MatrixTable.
VARIANT_MT="${OUTPUT_DIR}/small_variants.mt"
VcfToMt \
  --input "$SMALL_VARIANT_INPUT_VCF" \
  --output "$VARIANT_MT"

# Run Hail filtering on the small variant MatrixTable
# this step is the most resource-intensive, so I'd recommend running it on a VM with more resources
# aim for a machine with at least 8-cores, 16GB RAM
# the config entry 'RunHailFiltering.cores.small_variants' is consulted when setting up the PySpark cluster
# with a default of 8, but you can override this if you have more cores available.
FILTERED_SMALL_VARIANTS="${OUTPUT_DIR}/small_variants.vcf.bgz"
RunHailFiltering \
  --input "$VARIANT_MT" \
  --panelapp "$PANELAPP_RESULTS" \
  --pedigree "$PED_FILE" \
  --output "$FILTERED_SMALL_VARIANTS" \
  --clinvar "$CLINVAR_DECISIONS" \
  --pm5 "$CLINVAR_PM5" \
  --checkpoint small_var_checkpoint.mt

# Run the MOI validation.
MOI_RESULTS="${OUTPUT_DIR}/moi_results.json"
  ValidateMOI \
    --labelled_vcf "$FILTERED_SMALL_VARIANTS" \
    --output "$MOI_RESULTS" \
    --panelapp "$PANELAPP_RESULTS" \
    --pedigree "$PED_FILE" \
    --participant_panels "$MATCHED_PANELS"

# FindGeneSymbolMap
GENE_MAP="${OUTPUT_DIR}/symbol_to_ensg.json"
FindGeneSymbolMap \
  --input "$PANELAPP_RESULTS" \
  --output "$GENE_MAP"

# HPOFlagging
PHENO_ANNOTATED_RESULTS="${OUTPUT_DIR}/pheno_annotated_report.json"
PHENO_FILTERED_RESULTS="${OUTPUT_DIR}/pheno_filtered_report.json"
HPOFlagging \
  --input "$MOI_RESULTS" \
  --gene_map "$GENE_MAP" \
  --gen2phen "$GEN2PHEN" \
  --phenio "$PHENIO_DB" \
  --output "$PHENO_ANNOTATED_RESULTS" \
  --phenout "$PHENO_FILTERED_RESULTS"

# generate the HTML report
HTML_REPORT="${OUTPUT_DIR}/talos_results.html"
HTML_REPORT_LATEST="${OUTPUT_DIR}/talos_latest_results.html"
CreateTalosHTML \
  --input "$PHENO_ANNOTATED_RESULTS" \
  --panelapp "$PANELAPP_RESULTS" \
  --output "$HTML_REPORT" \
  --latest "$HTML_REPORT_LATEST"
