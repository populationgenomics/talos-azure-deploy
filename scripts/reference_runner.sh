#!/usr/bin/env bash

# This script manages gathering and preprocessing the reference dependencies for VEP and for Talos.

set -ex

# Verify that the environment variable REF_DIR is set, if not exit early.
if [ -z "$REF_DIR" ]; then
    echo "REF_DIR environment variable is not set. Exiting."
    exit 1
fi

# Assume that this directory exists since we expect it to be into the running container.
# This should probably be set at image build time as an environment variable.

### VEP dependencies

VEP_REF_DIR=$REF_DIR/vep
mkdir -p $VEP_REF_DIR

# VEP 110 cache - ~20 GiB
VEP_CACHE_DIR=$VEP_REF_DIR/vep_cache
mkdir -p $VEP_CACHE_DIR
VEP_CACHE_DL=/tmp/homo_sapiens_vep_110_GRCh38.tar.gz
mkdir -p /tmp
wget https://ftp.ensembl.org/pub/release-110/variation/indexed_vep_cache/homo_sapiens_vep_110_GRCh38.tar.gz -O $VEP_CACHE_DL --no-verbose
tar -xzf $VEP_CACHE_DL -C $VEP_CACHE_DIR
rm $VEP_CACHE_DL

# AlphaMissense files - ~600MiB
AM_FILE=$VEP_REF_DIR/AlphaMissense_hg38.tsv.gz
wget "https://storage.googleapis.com/dm_alphamissense/AlphaMissense_hg38.tsv.gz" -O $AM_FILE --no-verbose
tabix -s 1 -b 2 -e 2 -f -S 1 $AM_FILE

# Currently not being used, this appears not to be block gzipped and VEP complains about that.
# Since this is only used as a performance optimization it's not mandatory, but worth digging into.
# # Fasta reference - ~1GiB
# FASTA_FILE=$VEP_REF_DIR/Homo_sapiens.GRCh38.dna.toplevel.fa.gz
# wget -O $FASTA_FILE "ftp://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.toplevel.fa.gz"

# Loftee/LoF references
# Human ancestor file - ~1GiB
HA_FILE=$VEP_REF_DIR/human_ancestor.fa.gz
HA_FILE_INDEX=$VEP_REF_DIR/human_ancestor.fa.gz.fai
wget https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/human_ancestor.fa.gz -O $HA_FILE --no-verbose
wget https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/human_ancestor.fa.gz.fai -O $HA_FILE_INDEX --no-verbose

# GERP bigwig - ~12GiB
GERP_FILE=$VEP_REF_DIR/gerp_conservation_scores.homo_sapiens.GRCh38.bw
wget https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/gerp_conservation_scores.homo_sapiens.GRCh38.bw -O $GERP_FILE --no-verbose

# PhyloCSF SQL DB
SQL_FILE=$VEP_REF_DIR/loftee.sql
wget -qO- https://personal.broadinstitute.org/konradk/loftee_data/GRCh38/loftee.sql.gz | gunzip -c > $SQL_FILE

### Talos dependencies

TALOS_REF_DIR=$REF_DIR/talos
mkdir -p $TALOS_REF_DIR

# HPO.obo file
HPO_FILE=$TALOS_REF_DIR/HPO.obo
wget http://purl.obolibrary.org/obo/hp.obo -O $HPO_FILE --no-verbose

# Monarch HPO annotations
PHENIO_FILE=$TALOS_REF_DIR/phenio.db
wget -qO- https://data.monarchinitiative.org/monarch-kg/latest/phenio.db.gz | gunzip -c > $PHENIO_FILE

# JAX gene-to-phenotype annotations
GEN_2_PHEN_FILE=$TALOS_REF_DIR/genes_to_phenotype.txt
wget https://purl.obolibrary.org/obo/hp/hpoa/genes_to_phenotype.txt -O $GEN_2_PHEN_FILE --no-verbose

# Clinvarbitration data
CLINVARBITRATION_DIR=$TALOS_REF_DIR/clinvarbitration/
mkdir -p $CLINVARBITRATION_DIR
wget https://github.com/populationgenomics/ClinvArbitration/releases/download/1.5.0/november_release.tar.gz -O $CLINVARBITRATION_DIR/november_release.tar.gz --no-verbose
tar -xzf $CLINVARBITRATION_DIR/november_release.tar.gz -C $CLINVARBITRATION_DIR
rm $CLINVARBITRATION_DIR/november_release.tar.gz





