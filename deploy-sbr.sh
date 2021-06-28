#!/bin/bash -x

oc get deploy --all-namespaces -o json | jq -rc '.items[] | select(.metadata.name | contains("sbo-perf-app")).metadata.namespace' > workload.namespace.list

split -l 300 workload.namespace.list sbr-segment

for i in sbr-segment*; do
    for j in $(cat $i); do
        oc apply -f sbo-test.sbr.yaml -n $j --server-side=true;
        sleep 0.02s;
    done &
done

wait

rm -rf sbr-segment*
rm -rf workload.namespace.list