#!/bin/bash -xe

if [ -z "$QUAY_NAMESPACE" ]; then
    echo "QUAY_NAMESPACE environemnt variable needs to be set to a non-empty value"
    exit 1
fi

DT=$(date "+%F_%T")
RESULTS=results-$DT
mkdir -p $RESULTS

USER_NS_PREFIX=${1:-zippy}

# Resource counts
resource_counts(){
    echo -n "$1;"
    # All resource counts from user namespaces
    echo -n "$(oc get $1 --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace --ignore-not-found=true | grep $USER_NS_PREFIX | wc -l)"
    echo -n ";"
    # All resource counts from all namespaces
    echo "$(oc get $1 --all-namespaces -o name | wc -l)"
}

# Dig various timestamps out
timestamps(){
    SBR_JSON=$1
    DEPLOYMENTS_JSON=$2
    SBO_LOG=$3
    RESULTS=$4

    jq -rc '((.metadata.namespace) + ";" + (.metadata.name) + ";" + (.metadata.creationTimestamp) + ";" + (.status.conditions[] | select(.type=="Ready").lastTransitionTime))' $SBR_JSON > $RESULTS/tmp.csv
    echo "ServiceBinding;Created;ReconciledTimestamp;Ready;AllDoneTimestamp" > $RESULTS/sbr-timestamps.csv
    for i in $(cat $RESULTS/tmp.csv); do
        ns=$(echo -n $i | cut -d ";" -f1)
        name=$(echo -n $i | cut -d ";" -f2)
        echo -n $ns/$name;
        echo -n ";";
        echo -n $(date -d $(echo -n $i | cut -d ";" -f3) "+%F %T");
        echo -n ";";
        log=$(cat $SBO_LOG | grep $ns)
        date -d @$(echo $log | jq -rc 'select(.msg | contains("Reconciling")).ts' | head -n1) "+%F %T.%N" | tr -d "\n"
        echo -n ";";
        echo -n $(date -d $(echo -n $i | cut -d ";" -f4) "+%F %T");
        echo -n ";";
        done_ts=$(echo $log | jq -rc 'select(.msg | contains("Done")) | select(.retry==false).ts')
        if [ -n "$done_ts" ]; then
            date -d "@$done_ts" "+%F %T.%N"
        else
            echo ""
        fi
    done >> $RESULTS/sbr-timestamps.csv
    rm -f $RESULTS/tmp.csv

    jq -rc '((.metadata.namespace) + ";" + (.metadata.name) + ";" + (.metadata.creationTimestamp) + ";" + (.status.conditions[] | select(.type=="Available") | select(.status=="True").lastTransitionTime)) + ";" + (.metadata.managedFields[] | select(.manager=="manager").time)' $DEPLOYMENTS_JSON > $RESULTS/tmp.csv
    echo "Namespace;Deployment;Deployment_Created;Deployment_Available;Deployment_Updated_by_SBO;SB_Name;SB_created;SB_ReconciledTimestamp;SB_Ready;SB_AllDoneTimestamp" > $RESULTS/binding-timestamps.csv
    for i in $(cat $RESULTS/tmp.csv); do
        NS=$(echo -n $i | cut -d ";" -f1);
        echo -n $NS;
        echo -n ";";
        echo -n $(echo -n $i | cut -d ";" -f2);
        echo -n ";";
        echo -n $(date -d $(echo -n $i | cut -d ";" -f3) "+%F %T");
        echo -n ";";
        echo -n $(date -d $(echo -n $i | cut -d ";" -f4) "+%F %T");
        echo -n ";";
        echo -n $(date -d $(echo -n $i | cut -d ";" -f5) "+%F %T");
        echo -n ";";
        cat $RESULTS/sbr-timestamps.csv | grep $NS
    done >> $RESULTS/binding-timestamps.csv
    rm -f $RESULTS/tmp.csv
}

# Collect timestamps
{
# ServiceBinding resources in user namespaces
oc get sbr --all-namespaces -o json | jq -r '.items[] | select(.metadata.namespace | contains("'$USER_NS_PREFIX'"))' > $RESULTS/service-bindings.json

# Deployment resources in user namespaces
oc get deploy --all-namespaces -o json | jq -r '.items[] | select(.metadata.namespace | contains("'$USER_NS_PREFIX'"))' > $RESULTS/deployments.json

# ServiceBiding operator log
oc logs $(oc get $(oc get pods -n openshift-operators -o name | grep service-binding-operator) -n openshift-operators -o jsonpath='{.metadata.name}') -n openshift-operators > $RESULTS/service-binding-operator.log

timestamps $RESULTS/service-bindings.json $RESULTS/deployments.json $RESULTS/service-binding-operator.log $RESULTS
} &

# Collect resource counts
{
RESOURCE_COUNTS_OUT=$RESULTS/resource-count.csv
echo "Resource;UserNamespaces;AllNamespaces" > $RESOURCE_COUNTS_OUT
for i in $(oc api-resources --verbs=list --namespaced -o name); do
    resource_counts $i >> $RESOURCE_COUNTS_OUT;
done
} &

wait
