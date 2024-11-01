#!/usr/bin/env bash

# This script is an example of how to run Talos, and is not intended to be run as-is
# It can be run from any directory within the Talos image, or any environment where the
# Talos package is installed
#
# If this is run end-to-end in one

set -e

# set the path to use for an output directory
OUTPUT_DIR="/data/outputs/talos_rgp_$(date +%F)"
# OUTPUT_DIR="/data/outputs/talos_rgp_2024-10-03"
#OUTPUT_DIR="/data/outputs/talos_rgp_2024-09-06"
mkdir -p $OUTPUT_DIR

# pass the populated Config TOML file, and export as an environment variable
CONFIG_FILE="/data/config.toml"
export TALOS_CONFIG="$CONFIG_FILE"

# pass the Pedigree / phenopackets files to the script
PED_FILE="/data/generated/rgp_talos_filtered_phenopacket/pedigree.ped"
PHENOPACKET_FILE="/data/generated/rgp_talos_filtered_phenopacket/phenopackets.json"

# pass the MatrixTable of variants to the script
VARIANT_MT="/data/annotated_variants.mt"

# pass both ClinVar tables to the script
CLINVAR_DECISIONS="/data/clinvarbitration/24-09_v1.4.0/24-09/clinvar_decisions.ht"
CLINVAR_PM5="/data/clinvarbitration/24-09_v1.4.0/24-09/clinvar_pm5.ht"

# pass the HPO OBO file from http://purl.obolibrary.org/obo/hp.obo
# HPO_OBO="/data/hp.obo"
HPO_OBO="/data/hpo_terms.obo"

# [optional] pass the MatrixTable of SVs to the script
SV_MT="/data/phase4_RGP_high_specificity.annotated.filtered_no_outliers.mt"

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

# If you have SVs, run Hail filtering on the SV MatrixTable
if [ -n "$SV_MT" ]; then
  SV_VARIANT_VCF="${OUTPUT_DIR}/sv_variants.vcf.bgz"
  RunHailFilteringSV \
    --input "$SV_MT" \
    --panelapp "$PANELAPP_RESULTS" \
    --pedigree "$PED_FILE" \
    --output "$SV_VARIANT_VCF"
fi

# run the MOI validation
MOI_RESULTS="${OUTPUT_DIR}/moi_results.json"
# If the SV MatrixTable was provided, run the SV version of the validation
if [ -n "$SV_VARIANT_VCF" ]; then
    ValidateMOI \
      --labelled_vcf "$SMALL_VARIANT_VCF" \
      --labelled_sv "$SV_VARIANT_VCF" \
      --output "$MOI_RESULTS" \
      --panelapp "$PANELAPP_RESULTS" \
      --pedigree "$PED_FILE" \
      --participant_panels "$MATCHED_PANELS"
else
    ValidateMOI \
      --labelled_vcf "$SMALL_VARIANT_VCF" \
      --output "$MOI_RESULTS" \
      --panelapp "$PANELAPP_RESULTS" \
      --pedigree "$PED_FILE" \
      --participant_panels "$MATCHED_PANELS"
fi

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
  --gen2phen "/data/genes_to_phenotype.txt" \
  --phenio "/data/phenotype.db" \
  --output "$PHENO_ANNOTATED_RESULTS" \
  --phenout "$PHENO_FILTERED_RESULTS"

# Alternative (recent) paths for the above.
  # --gen2phen "/data/gene_pheno.tsv" \
  # --phenio "/data/phenio.db" \

# generate the HTML report
HTML_REPORT="${OUTPUT_DIR}/talos_results.html"
HTML_REPORT_LATEST="${OUTPUT_DIR}/talos_latest_results.html"
CreateTalosHTML \
  --input "$PHENO_ANNOTATED_RESULTS" \
  --panelapp "$PANELAPP_RESULTS" \
  --output "$HTML_REPORT" \
  --latest "$HTML_REPORT_LATEST"

# # generate the Seqr file
# SEQR_LABELS="${OUTPUT_DIR}/seqr_labels.json"
# PHENOTYPE_SPECIFIC_SEQR_LABELS="${OUTPUT_DIR}/phenotype_match_seqr_labels.json"
# GenerateSeqrFile "$MOI_RESULTS" "$SEQR_LABELS" "$PHENOTYPE_SPECIFIC_SEQR_LABELS"
