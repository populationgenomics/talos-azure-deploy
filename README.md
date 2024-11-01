# talos-deploy

This repository provides a streamlined reference implementation for users to see an example of how to implement the [Talos](https://github.com/populationgenomics/talos) pipeline for genetic variant prioritization and reanalysis. Further, it is intended to facilitate quick evaluation of talos on small datasets, either synthetic sample data or user-provided data. Information on each of these use cases is provided below.

## I want to try Talos on some sample data

A pre-built docker iamge that can be used to run talos end to end is available "this ACR"

### Pre-requisites

### Running Talos on sample data

We have provided a sample VCF, Ped file, and Phenopacket file in "this public storage account".

1. Configure your run specification yaml
2. Deploy the runtime azure resource
3. Kick off the run
4. Profit

### Explanation of what's happening

## I want to run Talos on my own data

### Pre-requisites

Same as above, plus your data need to be in cloud storage somewhere

requires make, terraform, az, jq, docker

## I am an advanced Talos user and I want to modify pipeline behavior

## I am an infrastructure administrator and I want to host my own talos-deploy Docker image

## Troubleshooting

1. Incorrect RBAC privileges to access data