#!usr/bin/env bash
source "${LIB_DIR}/common.sh"

APISERVER=https://kubernetes.default.svc
SERVICEACCOUNT=/run/secrets/kubernetes.io/serviceaccount
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)
TOKEN=$(cat ${SERVICEACCOUNT}/token)
CACERT=${SERVICEACCOUNT}/ca.crt

secret_exists() {
    secret_name="${1}"
    if [ "$(curl -s -o /dev/null -w "%{http_code}" --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/${NAMESPACE}/secrets/${secret_name})" == "200" ]; then
        echo "1"
    else
        echo "0"
    fi
}
secret_get() {
    secret_name="${1}"
    response_code="$(curl -o "/dev/shm/pijourney-k8s-${secret_name}" -w "%{http_code}" --silent --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/${NAMESPACE}/secrets/${secret_name})"

    if [ $? != 0 ]; then
        err "Curl exited with invalid responsecode when retriving secret ${secret_name}"
        exit 1
    elif [ "${response_code}" == "404" ]; then
        return
    elif [ "${response_code}" != "200" ]; then
        err "k3s responded with code ${response_code} when retriving secret ${secret_name}"
        exit 1
    else
        cat "/dev/shm/pijourney-k8s-${secret_name}"
    fi
}

create_secret() {
    secret_name="${1}"
    secret_data="${2}"
    curl --silent --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -X POST ${APISERVER}/api/v1/namespaces/${NAMESPACE}/secrets -d @- <<EOF
    {
        "kind": "Secret",
        "apiVersion": "v1",
        "metadata":{
            "name": "${secret_name}"
        },
        "data": { ${secret_data} }
    }
EOF
}
