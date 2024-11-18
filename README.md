# talos-deploy

This repository provides a streamlined reference implementation for users to see an example of how to implement the [Talos](https://github.com/populationgenomics/talos) pipeline for genetic variant prioritization and reanalysis in Microsoft Azure. Further, it is intended to facilitate quick evaluation of talos on small datasets, either synthetic sample data or user-provided data. Information on each of these use cases is provided below.

This is not intended to be an exhaustive guide as to the myriad ways to implement the Talos pipeline in Azure, but rather a starting point for users to get up and running quickly.

There are two basic use cases supported by this repository:
1. I want to try running Talos on some sample data
2. I want to run Talos on my own data

Even if you eventually want to run Talos on your own data, it's recommended to start with the sample data use case to get all the pre-requisites set up and to get a feel for how this Azure infrastructure is set up to run the Talos pipeline.

Loosely speaking, the order of operations to getting Talos running in your own Azure environment involves the following steps:

1. Get your local deployment environment and Azure environment set up
2. Deploy the Azure resources needed to run Talos
3. Build and push the docker images used by the pipeline
4. Prepare the reference data needed by the pipeline
5. Prepare the input data needed by the pipeline
6. Run the pipeline and review the results

Wherever possible, we've tried to automate these steps using makefiles and terraform scripts.

## Get your local deployment environment and Azure environment set up

### Development environment pre-requisites

This README has been tested on an Azure VM and WSL2 instance, both of which were running Ubuntu 22.04 LTS. In order to deploy this implementation of the Talos pipeline, you will need the following tools installed on your development environment:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [docker](https://docs.docker.com/engine/install/ubuntu/)
- [make](https://www.gnu.org/software/make/)

### Cloud pre-requisites

In order to deploy the Talos pipeline in Azure, you will need access to an Azure subscription where you have the necessary permissions to create resources.

You will want to make note of the tenant ID and subscription ID for the Azure subscription you will be using. You can find these values by running the following commands in the Azure CLI after logging in:

```bash
az account show --query tenantId -o tsv
az account show --query id -o tsv
```

## Deploy the Azure resources needed to run Talos

The `deploy` directory contains the terraform configuration files necessary to deploy the Azure resources needed to run the Talos pipeline. TODO: add instructions for other users as to how to make their own deployments.

## Build and push the docker images used by the pipeline

The Talos pipeline uses two docker images to run the primary pipeline stages (VEP annotation of input data and the Talos prioritization pipeline itself). These images are built using the Dockerfiles in the `docker` directory. The `Makefile` in the root of this repository provides a target to build and push these images to the Azure Container Registry (ACR) that you deployed above.

```bash
make update-images
```

Note: if you want to verify that the images were built and pushed to the ACR successfully, you can run the following command to double-check:

```bash
az acr repository list --name ${DEPLOYMENT_NAME}acr --output table
```

Where `DEPLOYMENT_NAME` is specific to your configuration and defined in `deploy/deployment.tf`.

This should return the following result

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

## Prepare the input data needed by the pipeline

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
cp path/to/your/data.vcf.gz .data/${DATASET_ID}/input/small_variants.vcf.gz
cp path/to/your/data.vcf.gz.tbi .data/${DATASET_ID}/input/small_variants.vcf.gz.tbi
cp path/to/your/data.ped .data/${DATASET_ID}/input/pedigree.ped
# Optional
cp path/to/your/data.json .data/${DATASET_ID}/phenopackets.json
```

** Note the specific naming conventions for the input files. At this time, the pipeline expects these files to be named as described above.**

## Run the pipeline and review the results

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
make mount-all
ls .data/<your_dataset_id>/output/talos_<datestamp>
```

The output of the pipeline will contain a number of files that are discussed in the parent Talos repository, but the primary outputs of interest are `pheno_annotated_report.json` and `talos_output.html`. Note the latter will not be present if no variants were prioritized by the pipeline.