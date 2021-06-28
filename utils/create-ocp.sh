#!/bin/bash

set -eo pipefail

## Parameters
# OI_VERSION="4.4.0-0.nightly-2020-01-22-045318"
# OCP4_AWS_CLUSTER_NAME_SUFFIX=""
# OCP_RELEASE_DIR="ocp-dev-preview"
# OCP_RELEASE_TYPE="latest"
# OCP_RELEASE="4.4"
# POST_CLUSTER_INFO_ON_SLACK="true"
# POST_CLUSTER_INFO_ON_GIST="true"
# INSTALL_TOOLCHAIN_OPERATOR="true"
# INSTALL_PIPELINES_OPERATOR="true"
# CLUSTER_BASENAME="dev-svc"
## Secrets
# DEV_SVC_INSTALL_CONFIG="/tmp/$CLUSTER_BASENAME-install-config.yaml"
# AWS_ACCESS_KEY_ID="..."
# AWS_SECRET_ACCESS_KEY="..."
# GIST_API_TOKEN="..."
# SLACK_API_TOKEN="..."

export TOOL_DIR="$(readlink -f $(dirname $0))"
export CLUSTER_BASENAME="${CLUSTER_BASENAME:-dev-svc}"
export INSTALL_TOOLCHAIN_OPERATOR="${INSTALL_TOOLCHAIN_OPERATOR:-false}"
export INSTALL_PIPELINES_OPERATOR="${INSTALL_PIPELINES_OPERATOR:-false}"
if [ -z $OCP_RELEASE ] && [ -z $OI_VERSION ]; then
    echo "At least one of OCP_RELEASE or OI_VERSION variables needs to be set."
    exit 1
fi

if [ -z $OCP_RELEASE ]; then
    #detect OCP_RELEASE for given OI_VERSION
    export OCP_RELEASE=$(echo $OI_VERSION | sed 's,\([0-9]\+\.[0-9]\+\)\..*,\1,g')
else
    #detect OI_VERSION for given OCP_RELEASE
    export OCP_RELEASE_TYPE=${OCP_RELEASE_TYPE:-latest}
    export OI_VERSION=${OI_VERSION:-$(curl -s -L https://mirror.openshift.com/pub/openshift-v4/clients/$OCP_RELEASE_DIR/$OCP_RELEASE_TYPE-$OCP_RELEASE/release.txt | grep 'Name:' | sed -e 's,Name:\s\+\(.*\),\1,g')}
fi

function print_operator_subscription {
    PACKAGE_NAME=$1
    OPSRC_NAME=$2
    CHANNEL=$3

    CSV_VERSION=$(${OC_BINARY} get packagemanifest $PACKAGE_NAME -o jsonpath='{.status.channels[?(@.name == "'$CHANNEL'")].currentCSV}')
    sed -e 's,REPLACE_CSV_VERSION,'$CSV_VERSION',g' $TOOL_DIR/subscription.template.yaml \
    | sed -e 's,REPLACE_CHANNEL,'$CHANNEL',g' \
    | sed -e 's,REPLACE_OPSRC_NAME,'$OPSRC_NAME',g' \
    | sed -e 's,REPLACE_NAME,'$PACKAGE_NAME',g';
}

function install_operator_subscription {
    if [[ ! -z $(${OC_BINARY} get packagemanifest | grep $1) ]]; then
        print_operator_subscription $1 $2 $3 | ${OC_BINARY} apply --wait -f -
    else
        echo "ERROR: packagemanifest $1 not found";
        exit 1;
    fi
}

function install_pipelines_operator {
    NAME=openshift-pipelines-operator-rh
    OPSRC_NAME=redhat-operators
    CHANNEL=ocp-4.4

    print_operator_subscription $NAME $OPSRC_NAME $CHANNEL | ${OC_BINARY} apply --wait  -f -
}

function install_toolchain_operator {
    NAME=codeready-toolchain-operator
    OPSRC_NAME=community-operators
    CHANNEL=alpha

    print_operator_subscription $NAME $OPSRC_NAME $CHANNEL | ${OC_BINARY} apply --wait  -f -
}

function add_user {
    HTPASSWD_FILE="./htpass"
    USERNAME="consoledeveloper"
    USERPASS="developer"
    HTPASSWD_SECRET="htpasswd-$USERNAME-secret"

    OC_USERS_LIST="$(${OC_BINARY} get users)"
    if echo "${OC_USERS_LIST}" | grep -q "${USERNAME}"; then
        echo -e "\n\033[0;32m \xE2\x9C\x94 User consoledeveloper already exists \033[0m\n"
        exit;
    fi
    htpasswd -cb $HTPASSWD_FILE $USERNAME $USERPASS

    ${OC_BINARY} get secret $HTPASSWD_SECRET -n openshift-config &> /dev/null \
    || ${OC_BINARY} create secret generic ${HTPASSWD_SECRET} --from-file=htpasswd=${HTPASSWD_FILE} -n openshift-config

    sed -e "s,HTPASSWD_SECRET,${HTPASSWD_SECRET},g" $TOOL_DIR/oauth.template.yaml | ${OC_BINARY} apply -f -

    sleep 10s
    ${OC_BINARY} create clusterrolebinding ${USERNAME}_role1 --clusterrole=self-provisioner --user=${USERNAME} || echo clusterrolebinding ${USERNAME}_role1 exists
    ${OC_BINARY} create clusterrolebinding ${USERNAME}_role2 --clusterrole=view --user=${USERNAME} || echo clusterrolebinding ${USERNAME}_role2 exists
    sleep 15s
    echo -e "\n\e[1;35m User consoledeveloper created with the password developer. Type the below\e[0m \n"
    echo -e "\n\e[1;32m ${OC_BINARY} login -u\e[3m \e[1;36mconsoledeveloper\e[0m \e[1;32m-p\e[3m \e[1;36mdeveloper\e[0m \n"
}

source $TOOL_DIR/setup-tools.sh

export OCP4_AWS_WORKSPACE=$WORKSPACE/ocp4-aws

mkdir -p $OCP4_AWS_WORKSPACE/vault

EXPIRATION_DATE=$(date -u -d "-2 hour ago" +%Y-%m-%dT%H:%M+00:00)
sed -e "s,@@EXPIRATION_DATE@@,$EXPIRATION_DATE,g" $DEV_SVC_INSTALL_CONFIG > $OCP4_AWS_WORKSPACE/vault/$CLUSTER_BASENAME-install-config.yaml

export OCP4_AWS_CLUSTER_NAME_SUFFIX=${OCP4_AWS_CLUSTER_NAME_SUFFIX:-${OCP_RELEASE}-$(date +%m%d%H)}

ocp4-aws -n $CLUSTER_BASENAME
ocp4-aws -u $CLUSTER_BASENAME

cd $OCP4_AWS_WORKSPACE/cluster
tar -czf $WORKSPACE/cluster-dir.tar.gz *
cd $WORKSPACE

description=$(ocp4-aws -i $CLUSTER_BASENAME | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g')


export KUBECONFIG="$OCP4_AWS_WORKSPACE/current/auth/kubeconfig"

if [ "$POST_CLUSTER_INFO_ON_GIST" == "true" ]; then
    GIST_ADD_API="https://api.github.com/gists"
    export GIST=$(curl -L -XPOST -d "{\"description\":\"$description\",\"public\":false,\"files\":{\"kubeconfig\":{\"content\":\"$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $KUBECONFIG)\"}}}" -H "Authorization: token $GIST_API_TOKEN" $GIST_ADD_API)
fi

#TODO: check operator_install logs for failures. If a failure occurs, do not print message to slack.
# log file = $OCP4_AWS_WORKSPACE/current/.openshift_install.log
# success message = 'time="2020-03-05T14:05:07Z" level=info msg="Install complete!"'

#--output

OUTPUT=$WORKSPACE/cluster-config.txt
ocp4-aws -i $CLUSTER_BASENAME > $OUTPUT
if [ "$POST_CLUSTER_INFO_ON_GIST" == "true" ]; then
    echo -n "kubeconfig: " >> $OUTPUT
    echo $GIST | jq -cr '.files.kubeconfig.raw_url' >> $OUTPUT
fi
echo "openshift-install: $OI_VERSION" >> $OUTPUT

SLACK_CHANNEL="${SLACK_CHANNEL:-#forum-appsvc-notify}"
#SLACK_TEAM="${SLACK_TEAM:-}"

SLACK_MESSAGE="$SLACK_TEAM Today's v$OCP_RELEASE dev cluster:\n\`\`\`\n$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $OUTPUT)\`\`\`\nPlease be aware that this cluster will be purged in a bit less then 10 hours."

echo "------"
echo $SLACK_MESSAGE
echo "------"

# add non-admin user
add_user

# install toolchain-operator
if [ "$INSTALL_TOOLCHAIN_OPERATOR" == "true" ]; then
    install_toolchain_operator
fi

# install pipelines-operator
if [ "$INSTALL_PIPELINES_OPERATOR" == "true" ]; then
    install_pipelines_operator
fi


if [ "$POST_CLUSTER_INFO_ON_SLACK" == "true" ]; then
    curl -XPOST -H "Content-Type: application/json" -H "Authorization: Bearer $SLACK_API_TOKEN" -d "{\"channel\":\"$SLACK_CHANNEL\",\"link_names\":\"true\",\"as_user\":\"true\",\"text\":\"$SLACK_MESSAGE\"}" 'https://coreos.slack.com/api/chat.postMessage'
fi
