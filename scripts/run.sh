#!/usr/bin/env bash

# This script manages the overall execution of the Talos pipeline, including localization of dependencies, 
# pre-processing and validation of data inputs, obtaining and pre-processing clinvar data, annotation of 
# genomic data using VEP, execution of the Talos prioritization pipeline, and delocalization of results and
# intermediate files.

# It expects only a single argument, which is the path to a configuration file in YAML format. This file specifies:
# - the location of input files in Azure Blob Storage (e.g. pedigree, phenopackets, variant data, etc.)
# - the location that output files should be written to in Azure Blob Storage
# - [optional] any parameter overrides that should be applied to the Talos pipeline

### Localize dependencies
DATA_DIR="./.data"
mkdir -p $DATA_DIR

## Fixed data dependencies
# TODO: consider caching these dependencies in Blob Storage to avoid repeated downloads from their respective sources on the internet.

REF_DIR=$DATA_DIR/reference
mkdir -p $REF_DIR

# HPO.obo file
HPO_FILE=$REF_DIR/HPO.obo
wget http://purl.obolibrary.org/obo/hp.obo -O $HPO_FILE

# Monarch HPO annotations
PHENIO_FILE=$REF_DIR/phenio.db
wget -qO- https://data.monarchinitiative.org/monarch-kg/latest/phenio.db.gz | gunzip -c > $PHENIO_FILE

# JAX gene-to-phenotype annotations
GEN_2_PHEN_FILE=$REF_DIR/genes_to_phenotype.txt
wget https://purl.obolibrary.org/obo/hp/hpoa/genes_to_phenotype.txt -O $GEN_2_PHEN_FILE

# Clinvarbitration data
CLINVARBITRATION_DIR=$DATA_DIR/clinvarbitration/
mkdir -p $CLINVARBITRATION_DIR
wget https://github.com/populationgenomics/ClinvArbitration/releases/download/1.5.0/november_release.tar.gz -O $CLINVARBITRATION_DIR/november_release.tar.gz
tar -xzf $CLINVARBITRATION_DIR/november_release.tar.gz -C $CLINVARBITRATION_DIR
rm $CLINVARBITRATION_DIR/november_release.tar.gz

## Cohort data files

INPUT_DIR=$DATA_DIR/input
mkdir -p $INPUT_DIR

# Save providing this parameter to every call of az storage blob download.
export AZURE_STORAGE_AUTH_MODE=login

# Small variant VCF - this is a required input for the talos pipeline. It should be a block-compressed VCF file 
# that has been called by Dragen, GATK, or a compatible variant calling pipeline. A genome reference of GRCh38 is assumed.
SMALL_VARIANT_VCF=$INPUT_DIR/small_variants.vcf.bgz
az storage blob download --account-name $SOURCE_VCF_STORAGE_ACCOUNT \
    --container-name $SOURCE_VCF_STORAGE_CONTAINER \
    --name $SOURCE_VCF_NAME \
    --file $SMALL_VARIANT_VCF
az storage blob download --account-name $SOURCE_VCF_STORAGE_ACCOUNT \
    --container-name $SOURCE_VCF_STORAGE_CONTAINER \
    --name $SOURCE_VCF_INDEX_NAME \
    --file $SMALL_VARIANT_VCF.tbi

# Pedigree file - this is a required input for the talos pipeline. It should be a tab-delimited file with columns following the PED/FAM file format.
PED_FILE=$INPUT_DIR/pedigree.ped
az storage blob download --account-name $SOURCE_PED_STORAGE_ACCOUNT \
    --container-name $SOURCE_PED_STORAGE_CONTAINER \
    --name $SOURCE_PED_NAME \
    --file $PED_FILE

# Phenopackets file - this is an optional input for the pipeline. It should be a JSON file following the phenopackets schema.
if [ -n "$SOURCE_PHENOPACKETS_STORAGE_CONTAINER" ] && [ -n "$SOURCE_PHENOPACKETS_NAME" ]; then
    PHENOPACKET_FILE=$INPUT_DIR/phenopackets.json
    az storage blob download \
        --account-name $SOURCE_PHENOPACKETS_STORAGE_ACCOUNT \
        --container-name $SOURCE_PHENOPACKETS_STORAGE_CONTAINER \
        --name $SOURCE_PHENOPACKETS_NAME \
        --file $PHENOPACKET_FILE
fi
# TODO: what to do if this isn't provided?

### Pre-process and validate data inputs
WORK_DIR=$DATA_DIR/intermediate_outputs
mkdir -p $WORK_DIR

# Get input files required by VEP

# TODO: consider azcopy instead of az cli for speed. This is ~20GiB.
# To obtain the cache file from Ensembl:
# wget https://ftp.ensembl.org/pub/release-110/variation/indexed_vep_cache/homo_sapiens_vep_110_GRCh38.tar.gz
VEP_CACHE_DIR=$DATA_DIR/vep_cache
mkdir -p $VEP_CACHE_DIR
az storage blob download --account-name $VEP_CACHE_STORAGE_ACCOUNT \
    --container-name $VEP_CACHE_STORAGE_CONTAINER \
    --name $VEP_CACHE_NAME \
    --file $VEP_CACHE_DIR/homo_sapiens_vep_110_GRCh38.tar.gz
tar -xzf $VEP_CACHE_DIR/homo_sapiens_vep_110_GRCh38.tar.gz -C $VEP_CACHE_DIR
rm $VEP_CACHE_DIR/homo_sapiens_vep_110_GRCh38.tar.gz

# AlphaMissense files - ~600MiB
AM_FILE=$DATA_DIR/AlphaMissense_hg38.tsv.gz
wget "https://storage.googleapis.com/dm_alphamissense/AlphaMissense_hg38.tsv.gz" -O $AM_FILE
tabix -s 1 -b 2 -e 2 -f -S 1 $AM_FILE

# Fasta reference - ~1GiB
FASTA_FILE=$DATA_DIR/Homo_sapiens.GRCh38.dna.toplevel.fa.gz
wget -O $FASTA_FILE "ftp://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.toplevel.fa.gz"

# Loftee/LoF references
# Human ancestor file - ~1GiB
wget -O .data/human_ancestor.fa.gz https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/human_ancestor.fa.gz
wget -O .data/human_ancestor.fa.gz.fai https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/human_ancestor.fa.gz.fai

# GERP bigwig - ~12GiB
# pulled updated path from https://github.com/konradjk/loftee/issues/96
# wget -O .data/gerp_conservation_scores.homo_sapiens.GRCh38.bw https://ftp.ensembl.org/pub/current_compara/conservation_scores/91_mammals.gerp_conservation_score/gerp_conservation_scores.homo_sapiens.GRCh38.bw
# Alternatively, the grch38 branch of loftee has this
wget -O .data/gerp_conservation_scores.homo_sapiens.GRCh38.bw https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/gerp_conservation_scores.homo_sapiens.GRCh38.bw

# PhyloCSF SQL DB
wget -qO- https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/loftee.sql.gz | gunzip  -c > .data/loftee.sql



docker run -it --mount type=bind,src="/home/azureuser/talos-deploy/.data",target=/talos-deploy msft_vep:110 /bin/bash

# DOESN'T WORK FASTA vep --format vcf --vcf --compress_output bgzip -o /talos-deploy/annotated.vcf.bgz -i /talos-deploy/input/small_variants.vcf.bgz --everything --mane_select --allele_number --minimal --species homo_sapiens --cache --offline --assembly GRCh38 --dir_cache /talos-deploy/vep_cache --fasta /talos-deploy/Homo_sapiens.GRCh38.dna.toplevel.fa.gz --plugin AlphaMissense,file=/talos-deploy/AlphaMissense_hg38.tsv.gz --plugin LoF,gerp_bigwig:/talos-deploy/gerp_conservation_scores.homo_sapiens.GRCh38.bw,human_ancestor_fa:/talos-deploy/human_ancestor.fa.gz,conservation_file:/talos-deploy/loftee.sql,loftee_path:$VEP_DIR_PLUGINS
# vep --format vcf --vcf --compress_output bgzip -o /talos-deploy/annotated.vcf.bgz -i /talos-deploy/input/small_variants.vcf.bgz --everything --mane_select --allele_number --minimal --species homo_sapiens --cache --offline --assembly GRCh38 --dir_cache /talos-deploy/vep_cache --plugin AlphaMissense,file=/talos-deploy/AlphaMissense_hg38.tsv.gz --plugin LoF,gerp_bigwig:/talos-deploy/gerp_conservation_scores.homo_sapiens.GRCh38.bw,human_ancestor_fa:/talos-deploy/human_ancestor.fa.gz,conservation_file:/talos-deploy/loftee.sql,loftee_path:$VEP_DIR_PLUGINS




