#!/usr/bin/env bash

# This script is an example of how to run Talos, and is not intended to be run as-is
# It can be run from any directory within the Talos image, or any environment where the
# Talos package is installed
#
# If this is run end-to-end in one

set -e

# set the path to use for an output directory
OUTPUT_DIR="/talos-deploy/outputs/talos_rgp_$(date +%F)"
mkdir -p $OUTPUT_DIR

# pass the populated Config TOML file, and export as an environment variable
CONFIG_FILE="/talos-deploy/config.toml"
export TALOS_CONFIG="$CONFIG_FILE"

# pass the Pedigree / phenopackets files to the script
PED_FILE="/talos-deploy/input/pedigree.ped"
PHENOPACKET_FILE="/talos-deploy/input/phenopackets.json"

# pass the MatrixTable of variants to the script
VARIANT_MT="/talos-deploy/annotated.mt"

# pass both ClinVar tables to the script
CLINVAR_DECISIONS="/talos-deploy/clinvarbitration/24-11/clinvar_decisions.ht"
CLINVAR_PM5="/talos-deploy/clinvarbitration/24-11/clinvar_pm5.ht"

HPO_OBO="/talos-deploy/reference/HPO.obo"

# TODO: MISSING
# VCFTOMT

# identify the PanelApp data to use
MATCHED_PANELS="${OUTPUT_DIR}/matched_panels.json"
GeneratePanelData \
  --input "$PHENOPACKET_FILE" \
  --output "$MATCHED_PANELS" \
  --hpo "$HPO_OBO"

# query PanelApp for panels
PANELAPP_RESULTS="${OUTPUT_DIR}/panelapp_results.json"
QueryPanelapp \
  --input "$MATCHED_PANELS" \
  --output "$PANELAPP_RESULTS"

# run Hail filtering on the small variant MatrixTable
# this step is the most resource-intensive, so I'd recommend running it on a VM with more resources
# aim for a machine with at least 8-cores, 16GB RAM
# the config entry 'RunHailFiltering.cores.small_variants' is consulted when setting up the PySpark cluster
# with a default of 8, but you can override this if you have more cores available.
SMALL_VARIANT_VCF="${OUTPUT_DIR}/small_variants.vcf.bgz"
RunHailFiltering \
  --input "$VARIANT_MT" \
  --panelapp "$PANELAPP_RESULTS" \
  --pedigree "$PED_FILE" \
  --output "$SMALL_VARIANT_VCF" \
  --clinvar "$CLINVAR_DECISIONS" \
  --pm5 "$CLINVAR_PM5" \
  --checkpoint small_var_checkpoint.mt

# run the MOI validation
MOI_RESULTS="${OUTPUT_DIR}/moi_results.json"
  ValidateMOI \
    --labelled_vcf "$SMALL_VARIANT_VCF" \
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
  --gen2phen "/talos-deploy/reference/genes_to_phenotype.txt" \
  --phenio "/talos-deploy/reference/phenio.db" \
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
