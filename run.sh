#!/usr/bin/env bash
set -e

ROOTPATH=${PWD}

# might need to sudo apt install -y zip
sh ${ROOTPATH}/build.sh

export INDEX_FILE="index.html"
export ERROR_DIR="errors"
export BUCKET="nitecon-s3site-example"
export PREFIX="mysite"
export USE_REWRITE="false"
export DEBUG="true"
export CORS="*"
export REQUEST_NO_CACHE="/testnocache"
export CACHE_EXPIRE_TTL=60
export CACHE_PURGE_TTL=90
export USE_CACHE=true
export STORAGE_TYPE=s3

${ROOTPATH}/.build/bin/hostx

