. ./renewGlobals.sh

AKS_RESOURCE_GROUP=$1; 
ORGNAME=${ORG_NAME}
SPN_USERNAME=$2;
SPN_PASSWORD=$3;
SPN_TANENT=$4;
TYPE=$5
cloudType=$6
error_exit(){
  if [ $1 -ne 0 ]; then
    echo "======== !!! ERROR WHILE CHAINCODE DEPLOYMENT !!! "$2" !!! RETURN CODE: "$1" !!! ==============="
    exit 1
  fi
}

echo "#===================================================================Login Into Azure Using SPN==================================================================#"

if [ "${cloudType,,}" = "${CLOUD_TYPE_CHINA,,}" ]; then
  az cloud set --name AzureChinaCloud 
fi


loginCommand="az login --service-principal --username $SPN_USERNAME --password $SPN_PASSWORD --tenant $SPN_TANENT"
$loginCommand
error_exit $? "Error While azure login"

mkdir -p ${PROFILE_LOCATION}

./getConnector.sh $AKS_RESOURCE_GROUP $cloudType | sed -e "s/{action}/gateway/g"| xargs curl > ${PROFILE_LOCATION}/$ORGNAME-ccp.json
./getConnector.sh $AKS_RESOURCE_GROUP $cloudType | sed -e "s/{action}/admin/g"| xargs curl > ${PROFILE_LOCATION}/$ORGNAME-admin.json
./getConnector.sh $AKS_RESOURCE_GROUP $cloudType | sed -e "s/{action}/msp/g"| xargs curl > ${PROFILE_LOCATION}/$ORGNAME-msp.json


CONNECTION_PROFILE_PATH=${PROFILE_LOCATION}/$ORGNAME-ccp.json
ADMIN_PROFILE_PATH=${PROFILE_LOCATION}/$ORGNAME-admin.json
MSP_PROFILE=${PROFILE_LOCATION}/$ORGNAME-msp.json

./certgen.sh $TYPE $ADMIN_PROFILE_PATH $CONNECTION_PROFILE_PATH $MSP_PROFILE