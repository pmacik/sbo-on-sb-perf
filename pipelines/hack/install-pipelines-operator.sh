#!/bin/bash -xe

OPERATOR_NAMESPACE=openshift-operators

kubectl apply -f - << EOD
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator-rh
  namespace: $OPERATOR_NAMESPACE
spec:
  channel: stable
  installPlanApproval: Automatic
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOD

#Wait for the operator to get up and running
retries=50
until [[ $retries == 0 ]]; do
  kubectl get deployment/openshift-pipelines-operator -n $OPERATOR_NAMESPACE >/dev/null 2>&1 && break
  echo "Waiting for openshift-pipelines-operator to be created in $OPERATOR_NAMESPACE namespace"
  sleep 5
  retries=$(($retries - 1))
done
kubectl rollout status -w deployment/openshift-pipelines-operator -n $OPERATOR_NAMESPACE