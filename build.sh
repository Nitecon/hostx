#!/usr/bin/env bash
set -e

ROOTPATH=${PWD}
VERSION=0.01
rm -rf ${ROOTPATH}/.build/
mkdir -p ${ROOTPATH}/.build/

if ! [ -x "$(command -v ko)" ]; then
    GO111MODULE=on GOOS=linux GOARCH=amd64 go build -ldflags "-s -w -X main.version=${VERSION}" -o ${ROOTPATH}/.build/bin/hostx cmd/main.go
fi

# might need to sudo apt install -y zip
cd .build/ && zip -r hostx.zip ./*
cd ${ROOTPATH}

