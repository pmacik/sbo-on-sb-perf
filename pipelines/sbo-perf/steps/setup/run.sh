#!/bin/bash -xe

ls -la /tmp/artifacts

git clone https://github.com/pmacik/sbo-on-sb-perf $WORKSPACE/src

curl -sSL -o $WORKSPACE/oc.tar.gz "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz"
tar -xvf $WORKSPACE/oc.tar.gz -C $WORKSPACE
rm -rvf $WORKSPACE/oc.tar.gz

oc version --client

#curl -Lo $WORKSPACE/operator-sdk https://github.com/operator-framework/operator-sdk/releases/download/v${OPERATOR_SDK_VERSION}/operator-sdk_linux_amd64
#chmod +x $WORKSPACE/operator-sdk
