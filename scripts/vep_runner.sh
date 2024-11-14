#!/usr/bin/env bash

# This script handles running VEP on an input VCF file.
# The requirements for input VCFs are listed in the top-level README.md file.

# This script is intended to run inside the vep-run Docker image and assumes that three environment variables
# are set:
# - VEP_DIR_PLUGINS: the directory where VEP plugins are located. This is normally set in the base docker image.
# - DATA_DIR: the directory where the input bgzipped VCF and index are located. For example, if DATA_DIR is set to /data
#     then it's assumed that at runtime the path /data/input/input.vcf.bgz and /data/input/input.vcf.bgz.tbi contain the
#     data to be processed. The output will be written to /data/output/annotated.vcf.bgz and /data/output/annotated.vcf.bgz.tbi.
# - REF_DIR: the directory where reference data is located. This includes the VEP cache, FASTA reference, and other files
#     required by VEP.

set -ex

# Verify that the environment variable VEP_DIR_PLUGINS is set, if not exit early.
if [ -z "$VEP_DIR_PLUGINS" ]; then
    echo "VEP_DIR_PLUGINS environment variable is not set. Exiting."
    exit 1
fi

# Verify that the environment variable REF_DIR is set, if not exit early.
if [ -z "$REF_DIR" ]; then
    echo "REF_DIR environment variable is not set. Exiting."
    exit 1
fi

# Verify that the environment variable DATA_DIR is set, if not exit early.
if [ -z "$DATA_DIR" ]; then
    echo "DATA_DIR environment variable is not set. Exiting."
    exit 1
fi

# Accept as an argument the dataset id, default to "example"
DATASET_ID=${1:-example}

# TODO, validate the presence of the input VCF file and index.
DATASET_DIR=$DATA_DIR/$DATASET_ID

# Assume that the output file is named annotated.vcf.bgz. Should be parametrized.
INPUT_VCF=$DATASET_DIR/input/small_variants.vcf.bgz

mkdir -p $DATASET_DIR/output/vep

vep --format vcf --vcf --compress_output bgzip -o $DATASET_DIR/output/vep/annotated.vcf.bgz \
    -i $INPUT_VCF \
    --everything \
    --mane_select \
    --allele_number \
    --minimal \
    --species homo_sapiens \
    --cache \
    --offline \
    --assembly GRCh38 \
    --dir_cache $REF_DIR/vep/vep_cache \
    --plugin AlphaMissense,file=$REF_DIR/vep/AlphaMissense_hg38.tsv.gz \
    --plugin LoF,gerp_bigwig:$REF_DIR/vep/gerp_conservation_scores.homo_sapiens.GRCh38.bw,human_ancestor_fa:$REF_DIR/vep/human_ancestor.fa.gz,conservation_file:$REF_DIR/vep/loftee.sql,loftee_path:$VEP_DIR_PLUGINS




