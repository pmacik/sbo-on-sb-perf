#!/bin/bash -xe

export OCP4_AWS_CLUSTER_NAME_SUFFIX=${OCP4_AWS_CLUSTER_NAME_SUFFIX:-$(date +%m%d%H%M)}

if [ -r /context/kubeconfig ]; then
    mv -vf /context/kubeconfig $WORKSPACE/kubeconfig
else
    $WORKSPACE/src/utils/create-ocp.sh
    mv -vf $WORKSPACE/ocp4-aws/current/auth/kubeconfig $WORKSPACE/kubeconfig
fi

curl -s https://raw.githubusercontent.com/redhat-developer/service-binding-operator/master/install.sh | OPERATOR_INDEX_IMAGE=quay.io/pmacik/servicebinding-operator:index SKIP_REGISTRY_LOGIN=true /bin/bash -s
