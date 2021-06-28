#!/bin/bash -e

# Environment
if [ -z "$QUAY_NAMESPACE" ]; then
    echo "QUAY_NAMESPACE environemnt variable needs to be set to a non-empty value"
    exit 1
fi

WS=$(pwd)

# Install Developer Sandbox
WSTC=$WS/toolchain-e2e.git
if [ ! -d $WSTC ]; then
    git clone https://github.com/codeready-toolchain/toolchain-e2e $WSTC
fi
cd $WSTC
git reset --hard
git pull
make dev-deploy-e2e

wait_for_deployment(){
    deployment=$1
    ns=$2
    #Wait for the operator to get up and running
    retries=50
    until [[ $retries == 0 ]]; do
        kubectl get deployment/$deployment -n $ns >/dev/null 2>&1 && break
        echo "Waiting for $deployment to be created in $ns namespace"
        sleep 5
        retries=$(($retries - 1))
    done
    kubectl rollout status -w deployment/$deployment -n $ns
}

wait_for_deployment host-operator $QUAY_NAMESPACE-host-operator
wait_for_deployment registration-service $QUAY_NAMESPACE-host-operator
wait_for_deployment member-operator $QUAY_NAMESPACE-member-operator
wait_for_deployment member-operator-webhook $QUAY_NAMESPACE-member-operator

# Install operators
cd $WS
./install-operators.sh

# Provision users
WL_SBR=$WS/sbo-test.with-sbr.user-workloads.yaml
WL_NO_SBR=$WS/sbo-test.without-sbr.user-workloads.yaml

echo "You can now provision Developer Sandbox users by running the following commands:"
echo ""
echo "  cd $(readlink -m $WSTC)"
echo ""
echo "and"
echo ""
echo "  go run setup/main.go --template=$(readlink -m $WL_SBR) --users 2000 --active 2000 --username zippy"
echo ""
echo "or"
echo ""
echo "  go run setup/main.go --template=$(readlink -m $WL_NO_SBR) --users 2000 --active 2000 --username zippy"
echo ""
