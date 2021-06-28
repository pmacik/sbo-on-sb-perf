#!/bin/bash -e

export OI_BINARY=$WORKSPACE/openshift-install
export OC_BINARY=$WORKSPACE/oc

cd $WORKSPACE

OC_URL=${OC_URL:-https://mirror.openshift.com/pub/openshift-v4/clients/${OCP_RELEASE_DIR}/${OI_VERSION}/openshift-client-linux-${OI_VERSION}.tar.gz}
wget -O oc.tar.gz "$OC_URL"
tar -xvf oc.tar.gz
rm -rvf oc.tar.gz

OI_URL=${OI_URL:-https://mirror.openshift.com/pub/openshift-v4/clients/${OCP_RELEASE_DIR}/${OI_VERSION}/openshift-install-linux-${OI_VERSION}.tar.gz}
wget -O oi.tar.gz "$OI_URL"
tar -xvf oi.tar.gz
rm -rvf oi.tar.gz

OCP_UTILS_DIR=$WORKSPACE/ocp-utils.git

if [ ! -d "$OCP_UTILS_DIR" ]; then
    git clone https://github.com/pmacik/ocp-utils $OCP_UTILS_DIR
fi
cd $OCP_UTILS_DIR
git reset --hard
git pull

export PATH=$PATH:$WORKSPACE:$OCP_UTILS_DIR/ocp4-aws

${OC_BINARY} version --client
${OI_BINARY} version

cd $WORKSPACE