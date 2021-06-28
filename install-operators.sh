#!/bin/bash -e
export SBO_INDEX_IMAGE=${SBO_INDEX_IMAGE:-quay.io/redhat-developer/servicebinding-operator:index}
export SBO_CHANNEL=${SBO_CHANNEL:-beta}
export SBO_PACKAGE=${SBO_PACKAGE:-service-binding-operator}
export SBO_CATSRC_NAMESPACE=${SBO_CATSRC_NAMESPACE:-openshift-marketplace}
export SBO_CATSRC_NAME=${SBO_CATSRC_NAME:-sbo-operators}

export RHOAS_INDEX_IMAGE=${RHOAS_INDEX_IMAGE:-quay.io/rhoas/service-operator-registry:autolatest}
export RHOAS_CHANNEL=${RHOAS_CHANNEL:-beta}
export RHOAS_PACKAGE=${RHOAS_PACKAGE:-rhoas-operator}
export RHOAS_CATSRC_NAMESPACE=${RHOAS_CATSRC_NAMESPACE:-openshift-marketplace}
export RHOAS_CATSRC_NAME=${RHOAS_CATSRC_NAME:-rhoas-operators}
export RHOAS_NAMESPACE=${RHOAS_NAMESPACE:-openshift-operators}

DOCKER_CFG=$(mktemp)
chmod -r $DOCKER_CFG

echo "Installing Service Binding Operator"
curl -s https://raw.githubusercontent.com/redhat-developer/service-binding-operator/master/install.sh | \
    OPERATOR_INDEX_IMAGE=$SBO_INDEX_IMAGE \
    OPERATOR_CHANNEL=$SBO_CHANNEL \
    OPERATOR_PACKAGE=$SBO_PACKAGE \
    CATSRC_NAMESPACE=$SBO_CATSRC_NAMESPACE \
    CATSRC_NAME=$SBO_CATSRC_NAME \
    SKIP_REGISTRY_LOGIN=true \
    DOCKER_CFG=$DOCKER_CFG \
    /bin/bash -s

rm -f $DOCKER_CFG

echo "Installing RHOAS Operator"
oc apply -f - << EOD
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: $RHOAS_CATSRC_NAME
  namespace: $RHOAS_CATSRC_NAMESPACE
spec:
  displayName: RHOAS Operators
  icon:
    base64data: ""
    mediatype: ""
  image: $RHOAS_INDEX_IMAGE
  priority: -400
  publisher: RHOAS
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 260s
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $RHOAS_PACKAGE
  namespace: $RHOAS_NAMESPACE
spec:
  channel: $RHOAS_CHANNEL
  installPlanApproval: Automatic
  name: $RHOAS_PACKAGE
  source: $RHOAS_CATSRC_NAME
  sourceNamespace: $RHOAS_CATSRC_NAMESPACE
EOD

#Wait for the operator to get up and running
retries=50
until [[ $retries == 0 ]]; do
  kubectl get deployment/rhoas-operator -n $RHOAS_NAMESPACE >/dev/null 2>&1 && break
  echo "Waiting for rhoas-operator to be created in $RHOAS_NAMESPACE namespace"
  sleep 5
  retries=$(($retries - 1))
done
kubectl rollout status -w deployment/rhoas-operator -n $RHOAS_NAMESPACE
