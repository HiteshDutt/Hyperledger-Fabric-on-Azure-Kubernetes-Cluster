. ./renewGlobals.sh

CHANNEL=$1
ORG_NAME=$2
ORG_DNS=$3
ORDERER_ORG_NAME=$4
ORDERER_ORG_DNS=$5
TYPE=$6
i=1
export INPUT_CERT=$7
IS_SYSTEM_CHANNEL=false
echo "#=========================================================RENEW ${ORG_NAME} ADMIN CERTIFICATE===================================#"
CURRENT_LOCATION=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ $CERT_LOCATION == "" ]];then
    CERT_LOCATION="$CRYPTO_CONFIG"
fi
export FABRIC_CFG_PATH="$CURRENT_LOCATION";
ORDERER="orderer$i.$ORDERER_ORG_DNS:443"
ORDERER_CA="$CERT_LOCATION/orderer/$ORDERER_ORG_NAME/orderer$i.$ORDERER_ORG_NAME/msp/tlscacerts/ca.crt"
export CORE_PEER_TLS_ENABLED=true
#export CORE_PEER_LOCALMSPID=$ORG_NAME
export CORE_PEER_LOCALMSPID=$ORDERER_ORG_NAME
#export CORE_PEER_TLS_ROOTCERT_FILE=$CERT_LOCATION/$TYPE/$ORG_NAME/$TYPE$i.$ORG_NAME/msp/tlscacerts/ca.crt
export CORE_PEER_TLS_ROOTCERT_FILE=$CERT_LOCATION/orderer/$ORDERER_ORG_NAME/orderer$i.$ORDERER_ORG_NAME/msp/tlscacerts/ca.crt
#export CORE_PEER_MSPCONFIGPATH=$CERT_LOCATION/$TYPE/$ORG_NAME/msp
export CORE_PEER_MSPCONFIGPATH=$CERT_LOCATION/orderer/$ORDERER_ORG_NAME/msp
#export CORE_PEER_ADDRESS="$TYPE$i.$ORG_DNS:443"
export CORE_PEER_ADDRESS=$ORDERER
echo "#=========================================================Getting ${CHANNEL} config block=========================================#"
mkdir -p $GENERATED_CONFIG_FILES
pbFileName=$GENERATED_CONFIG_FILES/config_block$i${CHANNEL}.pb
configFileName=$GENERATED_CONFIG_FILES/config$i${CHANNEL}.json
modifiedFileName=$GENERATED_CONFIG_FILES/modified_config$i${CHANNEL}.json
modifiedFileName2=$GENERATED_CONFIG_FILES/modified_config$i${CHANNEL}2.json
configPbFile=$GENERATED_CONFIG_FILES/config$i${CHANNEL}.pb
modifiedConfigPbFile=$GENERATED_CONFIG_FILES/modifiedconfig$i${CHANNEL}.pb
configUpdatePbFile=$GENERATED_CONFIG_FILES/config_update_$i_${CHANNEL}.pb
configUpdateJsonFile=$GENERATED_CONFIG_FILES/config_update_$i_${CHANNEL}.json
configUpdateEnvelopeJsonFile=$GENERATED_CONFIG_FILES/config_update_${i}_${CHANNEL}_in_envelope.json
configUpdateEnvelopePbFile=$GENERATED_CONFIG_FILES/config_update_${i}_${CHANNEL}_in_envelope.pb

downloadBlock(){
    ./bin/peer channel fetch config $pbFileName -o $ORDERER -c ${CHANNEL} --tls --cafile "$ORDERER_CA"
    ./bin/configtxlator proto_decode --input $pbFileName --type common.Block | jq .data.data[0].payload.data.config >$configFileName
    cp $configFileName $modifiedFileName
}

downloadBlock

echo "## Encode $TYPE"

if [ ${TYPE,,} == {"orderer",,} ]; then
    SETFORTYPE=Orderer
else
    SETFORTYPE=Application
fi

base64Cert=$(cat $INPUT_CERT | base64 -w 0)
replaceTarget=$(cat $modifiedFileName | jq  ".channel_group.groups.$SETFORTYPE.groups.$ORG_NAME.values.MSP.value.config.admins[]")
if [ $? -ne 0 ]; then
    echo "System channel please check consortium name in renewGlobals.sh default named to SampleConsortium"
     IS_SYSTEM_CHANNEL=true
    echo "======================= Update Sub Policy to admin ========================"
    ./updatePolicy.sh $CHANNEL $ORDERER_ORG_NAME $ORDERER_ORG_DNS $TYPE "Admins"
    downloadBlock
    replaceTarget=$(cat $modifiedFileName | jq  ".channel_group.groups.Consortiums.groups.$CONSORTIUM_NAME.groups.$ORG_NAME.values.MSP.value.config.admins[]")
fi

echo $replaceTarget
cat $modifiedFileName | sed -e "s/$replaceTarget/\"$base64Cert\"/g" > $modifiedFileName2
./bin/configtxlator proto_encode --input $configFileName --type common.Config --output $configPbFile
echo "DOne 1"
./bin/configtxlator proto_encode --input $modifiedFileName2 --type common.Config --output $modifiedConfigPbFile
echo "DOne 2"
./bin/configtxlator compute_update --channel_id ${CHANNEL} --original $configPbFile --updated $modifiedConfigPbFile --output $configUpdatePbFile
echo "DOne 3"
./bin/configtxlator proto_decode --input $configUpdatePbFile --type common.ConfigUpdate --output $configUpdateJsonFile
echo "DOne 4"
echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"${CHANNEL}\", \"type\":2}},\"data\":{\"config_update\":"$(cat $configUpdateJsonFile)"}}}" | jq . >$configUpdateEnvelopeJsonFile
echo "DOne 5"
./bin/configtxlator proto_encode --input $configUpdateEnvelopeJsonFile --type common.Envelope --output $configUpdateEnvelopePbFile
echo "DOne 6"
export CORE_PEER_MSPCONFIGPATH=$CERT_LOCATION/$TYPE/$ORG_NAME/msp
export CORE_PEER_ADDRESS="$TYPE$i.$ORG_DNS:443"
export CORE_PEER_LOCALMSPID=$ORG_NAME
export CORE_PEER_TLS_ROOTCERT_FILE=$CERT_LOCATION/$TYPE/$ORG_NAME/$TYPE$i.$ORG_NAME/msp/tlscacerts/ca.crt
./bin/peer channel update -f $configUpdateEnvelopePbFile -c ${CHANNEL} -o $ORDERER --tls true --cafile $ORDERER_CA
echo "DOne 7"

if [ $IS_SYSTEM_CHANNEL == "true" ]; then
    echo "======================= Update Sub Policy to writer ========================"
    ./updatePolicy.sh $CHANNEL $ORDERER_ORG_NAME $ORDERER_ORG_DNS $TYPE "Writers"
fi