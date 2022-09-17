CLOUD_TYPE_CHINA=CHINA
adminNamespace=hlf-admin
nodeNamespace=hlf
caNamespace=ca
toolsNamespace=tools
PROFILE_LOCATION=/tmp/profile
CRYPTO_CONFIG=/tmp/cryptoconfig
CRYPTO_CONFIG_NEW=${CRYPTO_CONFIG}/new-certs
GENERATED_CONFIG_FILES=/tmp/configfiles
ORG_DETAIL_DATA=$(kubectl get cm org-detail -n ${adminNamespace} -o json | jq -r '.data')
CONSORTIUM_NAME="SampleConsortium"
DOMAIN_NAME=$(echo $ORG_DETAIL_DATA | jq -r '.domainName')
NODE_COUNT=$(echo $ORG_DETAIL_DATA | jq -r '.nodeCount')
ORG_NAME=$(echo $ORG_DETAIL_DATA | jq -r '.orgName')
CA_CREDENTIAL_DATA=$(kubectl get secret ca-credentials -n ${toolsNamespace} -o json | jq -r '.data')
CA_PASSWORD=$(echo $CA_CREDENTIAL_DATA | jq -r '."ca-admin-password"' | base64 -d)
CA_USER=$(echo $CA_CREDENTIAL_DATA | jq -r '."ca-admin-user"' | base64 -d)
# CAServerName="ca.ca.svc.cluster.local."
# CAServerPort="7054"
CAServerName="ca.${DOMAIN_NAME}"
CAServerPort="443"


verifyResult() {
  if [ $1 -ne 0 ]; then
    logMessage "Error" "$2" "$3"  
    exit 1
  fi
}