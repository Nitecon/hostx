#!/usr/bin/env bash
set -e

ROOTPATH=${PWD}

# might need to sudo apt install -y zip
sh ${ROOTPATH}/build.sh

cd ${ROOTPATH}/terraform/examples/simple
terraform init
terraform destroy -var-file="simple.tfvars" -auto-approve

