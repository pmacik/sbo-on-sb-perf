#!/bin/bash -xe

export SBO_PERF_RUN_ID=$(date +%Y-%m-%d_%H:%M:%S)-$HOSTNAME
echo $SBO_PERF_RUN_ID > $WORKSPACE/sbo-perf-run.id

mkdir -p ${WORKSPACE}/src
mkdir -p ${WORKSPACE}/bin

git clone https://github.com/pmacik/sbo-on-sb-perf $WORKSPACE/src

curl -sSL -o $WORKSPACE/oc.tar.gz "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz"
tar -xvf $WORKSPACE/oc.tar.gz -C $WORKSPACE/bin
rm -rvf $WORKSPACE/oc.tar.gz

chmod +x $WORKSPACE/bin/*

oc version --client
kubectl version --client

cp -rvf $WORKSPACE/* $METRICS/

#curl -Lo $WORKSPACE/operator-sdk https://github.com/operator-framework/operator-sdk/releases/download/v${OPERATOR_SDK_VERSION}/operator-sdk_linux_amd64
#chmod +x $WORKSPACE/operator-sdk
