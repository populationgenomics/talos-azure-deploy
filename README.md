# talos-deploy

This repository provides a streamlined reference implementation for users to see an example of how to implement the [Talos](https://github.com/populationgenomics/talos) pipeline for genetic variant prioritization and reanalysis in Microsoft Azure. It is intended to facilitate quick evaluation of talos on small datasets, either synthetic sample data or user-provided data. Information on each of these use cases is provided below.

This is not intended to be an exhaustive guide as to the myriad ways to implement the Talos pipeline in Azure, rather a starting point for users to get up and running quickly. There are two basic use cases supported by this repository:
1. I want to try running Talos on some sample data
2. I want to run Talos on my own data

Even if you eventually want to run Talos on your own data, it's recommended to start with the sample data use case to get all the prerequisites set up and to get a feel for how Azure resources are configured to run the Talos pipeline. This README will walk you through how to create the necessary Azure infrastructure, how to set up your references and data, and how to run a Talos job against the data.

## Local environment

### Dev environment prerequisites

This README has been tested on an Azure VM and WSL2 instance, both of which were running Ubuntu 22.04 LTS. In order to deploy this implementation of the Talos pipeline, you will need the following tools installed on your development environment:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [docker](https://docs.docker.com/engine/install/ubuntu/)
- [make](https://www.gnu.org/software/make/)

Most of the job build/run tasks are implemented as targets in the `Makefile` at the root of this repository - all `make` commands should be run from this root. You will need `sudo` permissions to run the file share `mount` targets.

### Cloud prerequisites

In order to deploy the Talos pipeline in Azure, you will need access to an Azure subscription where you have the necessary permissions to create resources.

You will want to make note of the tenant ID and subscription ID for the Azure subscription you will be using. You can find these values by running the following commands in the Azure CLI after logging in:

```bash
az account show --query tenantId -o tsv
az account show --query id -o tsv
```

## Azure infrastructure

The `deploy` directory contains template and configuration files for deploying the required Azure pipeline resources with Terraform.  To create a new deployment, first fill in the `deploy/deployment.env.template` file with the necessary values and rename it to `deploy/deployment.env`. This file will be referenced by various `make` commands to locate your Azure infrastructure.

```bash
# Tenant and subscription in which to deploy all resources.
export DEPLOYMENT_TENANT=<TENANT_ID>
export DEPLOYMENT_SUBSCRIPTION=<SUBSCRIPTION_ID>
# Master deployment name, used to derive various deployment-specific Azure resource names. To avoid any potential
# Azure namespace conflicts it should be globally unique across Azure, between 8-16 lowercase characters only.
export DEPLOYMENT_NAME=<NAME>
# Azure region (e.g. "eastus").
export DEPLOYMENT_REGION=<REGION>
```

> _**Optionally configuring remote state:**_ By default Terraform will create machine-local `.tfstate` state file upon initializing a new deployment with `terraform init`. To configure this deployment instead for a remote/shared state backend, fill in `deploy/backend.tf.template` with the appropriate values pointing to a container in an Azure Storage Account and rename the file to `deploy/backend.tf`.

Once `deployment.env` is initialized, use `make` to generate your deployment-specific Terraform variables file:

```bash
# Run from the repo root:
make deploy-config
```

This creates a file named `deploy/config.auto.tfvars` with the your deployment configuration that Terraform will read in automatically when run. You can now deploy the Azure resources with:

```bash
cd deploy
terraform init
terraform apply
```

> Note: `deployment.env` is `.gitignore`'d - other developers collaborating on the same deployment will need their own local copy of this file.

## Docker images

The Talos pipeline uses two docker images to run the primary pipeline stages (VEP annotation of input data and the Talos prioritization pipeline itself). These images are built using the Dockerfiles in the `docker` directory. You can use `make` to build and push these images to the Azure Container Registry (ACR) that you deployed above.

```bash
make update-images
```

To verify that the images were built and pushed to the ACR successfully, you can run the following command to double-check:
```bash
make list-images
```

This should return the following result:

```text
Result
---------
talos-run
vep-run
```

## Preparing reference data

The Talos pipeline -- and the VEP annotation pipeline (which talos depends on) -- require reference data to run. These reference data includes the VEP cache, VEP plugin data, Talos' preprocessed ClinVar inputs, etc. They are all pulled from sources across the internet and copying them into the environment where Talos will run can be slow. To optimize this, and to minimize load on those 3rd party servers, we perform a one-time copy of the required reference data to an Azure Blob Storage account in the same region where we intend to run Talos.

There are currently two ways to prepare the reference data, locally, or using an Azure Container App to do the work for you.

### Preparing reference data locally

Note: to perform this step on your local development machine, you will need at least 150 GiB of free disk space on the same mount point where you have the `talos-deploy` repository cloned.

To prepare the reference data locally, run the following commands:

```bash
# Locally mount the "reference" Azure Blob Storage File Share at `.reference`.
make mount-share SHARE_NAME=reference
make run-reference-job-local
```

### Prepare reference data using an Azure Container App

The Azure infrastructure you just deployed provides a convenient mechanism for executing containerized jobs in the cloud. To prepare the reference data using an Azure Container App, run the following commands:

```bash
make run-reference-job
```

## Preparing input data

The Talos pipeline has three required data inputs and one optional data input:
- A block-compressed VCF file containing the genetic variants to be analyzed
- The corresponding index file for the VCF file
- A pedigree file in PLINK format
- [Optional] A JSON-formatted phenopacket file containing the phenotypic data for the individuals in the pedigree

The VCF and index file need to be block-compressed using bgzip and indexed using tabix. The VCF must conform to the VCF specification and be normalized; multi-allelic variants should be split out into individual rows.

The pedigree file should be in the [PLINK format](https://www.cog-genomics.org/plink2/formats#fam). It should be named with the extension `.ped`, as opposed to the `.fam` extension.

If provided, the phenopacket file should conform to the [Phenopackets schema](https://phenopacket-schema.readthedocs.io/en/latest/index.html) and be in the JSON file format.

The input data files need to be staged in the Azure Blob Storage "data" File Share deployed above as part of the Talos Azure resources in order to be accessible to the Talos job at runtime. The required input files should be in a 
subfolder in this File Share named with a unique "DATASET_ID". The files can be named whatever you like, however there can only be one of each VCF, index, pedigree, and phenopacket file in each dataset folder.

```text
data
└── ${DATASET_ID}
    ├── my_variants.vcf.gz
    ├── my_variants.vcf.gz.tbi
    ├── my_pedigree.ped
    └── my_phenopacket.json
```

where `${DATASET_ID}` is a unique identifier for the dataset you are analyzing. To facilitate viewing and preparing data on this file share you can mount it locally at `.data` with the following `make` command:

```bash
make mount-share SHARE_NAME=data
```

### Using the provided example dataset

We have provided an example dataset in the `deploy/example-dataset` directory of this repository. This dataset is a small VCF file containing a few genetic variants, a corresponding pedigree file, and an optional phenopacket file. The infrastructure deploy process has automatically populated it to the "data" file share with a `${DATASET_ID}` of `example-dataset`. You should be able to view these data on the locally-mounted share:

```bash
ls .data/example-dataset
```

### Using your own data

If you wish you use your own data, you should first localize the input data to your development environment using whatever tools are appropriate given the storage location of the source data. We strongly recommend [azcopy](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10) for transfers within Azure. Once localized, you can use the following commands to stage the data to the mounted Azure Blob Storage File Share:

```bash
DATASET_ID="my_data" # or whatever you want to call this project
cp path/to/your/data.vcf.gz .data/${DATASET_ID}/small_variants.vcf.gz
cp path/to/your/data.vcf.gz.tbi .data/${DATASET_ID}/small_variants.vcf.gz.tbi
cp path/to/your/data.ped .data/${DATASET_ID}/pedigree.ped
# Optional
cp path/to/your/data.json .data/${DATASET_ID}/phenopackets.json
```

** Note that while the specific names of the VCF, pedigree, and phenopackets files can be whatever you want them to be, the extensions should be gz, tbi, ped, and json. Further, there should only be one file of each of these types in the `{$DATASET_ID}` folder.**

## Running jobs

Once you have the reference data and input data staged in the Azure Blob Storage account, you can run the Talos pipeline using the following commands:

```bash
make run-vep-job DATASET_ID=<your_dataset_id>
```

This command will result in a json blob output, from which you can extract the job execution name, it should be prefixed with `job-runner` and look like `job-runner-abcdef`. You then
use another make target to check the status of this job:

```bash
make get-job-status JOB_EXECUTION_NAME=<JOB_EXECUTION_NAME>
```

When the job status is returned as complete, then you can run the second step in the pipeline.

```bash
make run-talos-job DATASET_ID=<your_dataset_id>
```

These steps will run VEP and the core Talos pipeline on the input data you provided. On the example dataset this should take about 10 minutes to run. On larger datasets, the execution time will scale approximately linearly with the number of variants in the input VCF.

After successful execution, the output of the pipeline will be staged in the Azure Blob Storage account associated with this deployment and can be viewed in your development environment by running the following commands:

```bash
make mount-share # if .data not already mounted
ls .data/<your_dataset_id>/talos_<datestamp>
```

The output of the pipeline will contain a number of files that are discussed in the parent Talos repository, but the primary outputs of interest are `pheno_annotated_report.json` and `talos_output.html`. Note the latter will not be present if no variants were prioritized by the pipeline.