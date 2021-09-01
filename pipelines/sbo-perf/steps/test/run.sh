#!/bin/bash -xe

export SBO_PERF_RUN_ID=$(cat $WORKSPACE/sbo-perf-run.id)
oc version

cd $WORKSPACE/src
export OUTPUT_DIR=$WORKSPACE/load
export USER_NS_PREFIX=${USER_NS_PREFIX:-sbo-perf}

NS=${NS:-10} S=${S:-5} SD=${SD:-5} C=${C:-5} CD=${CD:-5} B=${B:-1} ./generate-workloads.sh

cat $OUTPUT_DIR/scale-{ns,secret,cm,app,bsvc,sbr}.yaml | oc apply -f - --wait --server-side=true


echo "Waiting for all Service Bindings to get Ready"

retries=3600
until [[ $retries == 0 ]]; do
    NUMBER_OF_SBR=$(oc get sbr --all-namespaces -o yaml | yq -rc '.items[] | select(.metadata.namespace | startswith("'$USER_NS_PREFIX'")).metadata.name' | wc -l)
    NUMBER_OF_READY_SBR=$(oc get sbr --all-namespaces -o yaml | yq -rc '.items[] | select(.metadata.namespace | startswith("'$USER_NS_PREFIX'")).status.conditions[] | select(.type == "Ready") | select(.status == "True").status' | wc -l)
    [ $NUMBER_OF_SBR -eq $NUMBER_OF_READY_SBR ] && break
    echo "Only $NUMBER_OF_READY_SBR/$NUMBER_OF_SBR service bindings is ready, waiting until all get ready"
    sleep 5
    retries=$(($retries - 1))
done

echo "Waiting for all Deployments to get Available"

retries=3600
until [[ $retries == 0 ]]; do
    NUMBER_OF_DEPLOYMENTS=$(oc get deploy --all-namespaces -o yaml | yq -rc '.items[] | select(.metadata.namespace | startswith("'$USER_NS_PREFIX'")).metadata.name' | wc -l)
    NUMBER_OF_AVAILABLE_DEPLOYMENTS=$(oc get deploy --all-namespaces -o yaml | yq -rc '.items[] | select(.metadata.namespace | startswith("'$USER_NS_PREFIX'")).status.conditions[] | select(.type == "Available") | select(.status == "True").status' | wc -l)
    [ $NUMBER_OF_DEPLOYMENTS -eq $NUMBER_OF_AVAILABLE_DEPLOYMENTS ] && break
    echo "Only $NUMBER_OF_AVAILABLE_DEPLOYMENTS/$NUMBER_OF_DEPLOYMENTS deployments are available, waiting until all get available"
    sleep 5
    retries=$(($retries - 1))
done

./collect-results.sh $USER_NS_PREFIX

# Archive artifacts
mkdir -p /mnt/artifacts/$SBO_PERF_RUN_ID
cp -rvf results* /mnt/artifacts/$SBO_PERF_RUN_ID/
