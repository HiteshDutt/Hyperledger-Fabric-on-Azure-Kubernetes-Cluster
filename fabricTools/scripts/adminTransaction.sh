. ./renewGlobals.sh

CHANNEL=$1
ORG_NAME=$2
ORG_DNS=$3
ORDERER_ORG_NAME=$4
ORDERER_ORG_DNS=$5
TYPE=$6
i=1
export INPUT_CERT=$7
echo "#=========================================================RENEW ${ORG_NAME} ADMIN CERTIFICATE===================================#"
CURRENT_LOCATION=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ $CERT_LOCATION == "" ]];then
    CERT_LOCATION="$CRYPTO_CONFIG"
fi
export FABRIC_CFG_PATH="$CURRENT_LOCATION";
ORDERER="orderer$i.$ORDERER_ORG_DNS:443"
ORDERER_CA="$CERT_LOCATION/orderer/$ORDERER_ORG_NAME/orderer$i.$ORDERER_ORG_NAME/msp/tlscacerts/ca.crt"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=$ORG_NAME
#export CORE_PEER_LOCALMSPID=$ORDERER_ORG_NAME
export CORE_PEER_TLS_ROOTCERT_FILE=$CERT_LOCATION/$ORG_NAME/$TYPE$i.$ORG_NAME/msp/tlscacerts/ca.crt
#export CORE_PEER_TLS_ROOTCERT_FILE=$CERT_LOCATION/$ORDERER_ORG_NAME/orderer$i.$ORDERER_ORG_NAME/msp/tlscacerts/ca.crt
export CORE_PEER_MSPCONFIGPATH=$CERT_LOCATION/$TYPE/$ORG_NAME/msp
#export CORE_PEER_MSPCONFIGPATH=$CERT_LOCATION/orderer/$ORDERER_ORG_NAME/msp
export CORE_PEER_ADDRESS="$TYPE$i.$ORG_DNS:443"
#export CORE_PEER_ADDRESS=$ORDERER
echo "#=========================================================Getting ${CHANNEL} config block=========================================#"
mkdir -p $GENERATED_CONFIG_FILES
pbFileName=$GENERATED_CONFIG_FILES/config_block_orderer$i${CHANNEL}.pb
./bin/peer channel fetch config $pbFileName -o $ORDERER -c ${CHANNEL} --tls --cafile "$ORDERER_CA"
configFileName=$GENERATED_CONFIG_FILES/config$i${CHANNEL}.json
./bin/configtxlator proto_decode --input $pbFileName --type common.Block | jq .data.data[0].payload.data.config >$configFileName
modifiedFileName=$GENERATED_CONFIG_FILES/modified_config$i${CHANNEL}.json
modifiedFileName2=$GENERATED_CONFIG_FILES/modified_config$i${CHANNEL}2.json
cp $configFileName $modifiedFileName

echo "## Encode $TYPE"

if [ ${TYPE,,} == {"orderer",,} ]; then
    SETFORTYPE=Orderer
else
    SETFORTYPE=Application
fi

base64Cert=$(cat $INPUT_CERT | base64 -w 0)
#base64Cert=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN3akNDQW1tZ0F3SUJBZ0lVY25Zdm5DaGZHdGp2YnJDWDQvS2lJblNKRmFNd0NnWUlLb1pJemowRUF3SXcKY1RFTE1Ba0dBMVVFQmhNQ1ZWTXhFekFSQmdOVkJBZ01DbGRoYzJocGJtZDBiMjR4RnpBVkJnTlZCQW9NRGtSbApkalZQY21SbGNtVnlUM0puTVJjd0ZRWURWUVFMREE1RVpYWTFUM0prWlhKbGNrOXlaekViTUJrR0ExVUVBd3dTCmNtTmhMa1JsZGpWUGNtUmxjbVZ5VDNKbk1CNFhEVEl5TURreE5URXdORFl3TUZvWERUSXlNRGt5TlRFd05URXcKTUZvd1NERVhNQlVHQTFVRUNoTU9SR1YyTlU5eVpHVnlaWEpQY21jeERqQU1CZ05WQkFzVEJXRmtiV2x1TVIwdwpHd1lEVlFRREV4UmhaRzFwYmk1RVpYWTFUM0prWlhKbGNrOXlaekJaTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5CkF3RUhBMElBQkM0N1VxbTQ3QkNqY0w4RkFMOFJ5NFZLZHNLRkhPZ3l0S1ZFNGR6SGxEMjV4R3lkZXY0emx6UmYKMS9XMnVYTTFqUVRKRjVic0JCQ0llQjNWdmk5RlZpZWpnZ0VHTUlJQkFqQU9CZ05WSFE4QkFmOEVCQU1DQjRBdwpEQVlEVlIwVEFRSC9CQUl3QURBZEJnTlZIUTRFRmdRVTAwTDBIUktQcFFIY0JjVzg0QWMrWmR3RUxiSXdId1lEClZSMGpCQmd3Rm9BVUJnVENxRTVSRi9DMFNid0Q5WXdGTDd5bHVUVXdGd1lEVlIwUkJCQXdEb0lNWm1GaWNtbGoKTFhSdmIyeHpNSUdJQmdncUF3UUZCZ2NJQVFSOGV5SmhkSFJ5Y3lJNmV5SmhZbUZqTG1sdWFYUWlPaUowY25WbApJaXdpWVdSdGFXNGlPaUowY25WbElpd2lhR1l1UVdabWFXeHBZWFJwYjI0aU9pSWlMQ0pvWmk1RmJuSnZiR3h0ClpXNTBTVVFpT2lKaFpHMXBiaTVFWlhZMVQzSmtaWEpsY2s5eVp5SXNJbWhtTGxSNWNHVWlPaUpoWkcxcGJpSjkKZlRBS0JnZ3Foa2pPUFFRREFnTkhBREJFQWlBb08vUmdydThXSllVUEpaUTRSWk9IVjIyTWhGbmNXRDBmZ0phWApKQWVzQndJZ0xRWEdRU3FkUkxvQXU2TndnZ2ZSN2gzVUdzY3doK2JoNmVSTDJNSTd3NGc9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
#cat $modifiedFileName | jq  ".channel_group.groups.$SETFORTYPE.groups.$ORG_NAME.values.MSP.value.config.admins =  [\"$base64Cert\"]" > $modifiedFileName2
replaceTarget=$(cat $modifiedFileName | jq  ".channel_group.groups.$SETFORTYPE.groups.$ORG_NAME.values.MSP.value.config.admins[]")
if [ $? -ne 0 ]; then
    echo "System channel please check consortium name in renewGlobals.sh default named to SampleConsortium"
    replaceTarget=$(cat $modifiedFileName | jq  ".channel_group.groups.Consortiums.groups.$CONSORTIUM_NAME.groups.$ORG_NAME.values.MSP.value.config.admins[]")
fi

echo $replaceTarget
cat $modifiedFileName | sed -e "s/$replaceTarget/$replaceTarget,\"$base64Cert\"/g" > $modifiedFileName2
configPbFile=$GENERATED_CONFIG_FILES/config$i${CHANNEL}.pb
./bin/configtxlator proto_encode --input $configFileName --type common.Config --output $configPbFile
echo "DOne 1"
modifiedConfigPbFile=$GENERATED_CONFIG_FILES/modifiedconfig$i${CHANNEL}.pb
./bin/configtxlator proto_encode --input $modifiedFileName2 --type common.Config --output $modifiedConfigPbFile
echo "DOne 2"
configUpdatePbFile=$GENERATED_CONFIG_FILES/config_update_$i_${CHANNEL}.pb
./bin/configtxlator compute_update --channel_id ${CHANNEL} --original $configPbFile --updated $modifiedConfigPbFile --output $configUpdatePbFile
echo "DOne 3"
configUpdateJsonFile=$GENERATED_CONFIG_FILES/config_update_$i_${CHANNEL}.json
./bin/configtxlator proto_decode --input $configUpdatePbFile --type common.ConfigUpdate --output $configUpdateJsonFile
echo "DOne 4"
configUpdateEnvelopeJsonFile=$GENERATED_CONFIG_FILES/config_update_${i}_${CHANNEL}_in_envelope.json
echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"${CHANNEL}\", \"type\":2}},\"data\":{\"config_update\":"$(cat $configUpdateJsonFile)"}}}" | jq . >$configUpdateEnvelopeJsonFile
echo "DOne 5"
configUpdateEnvelopePbFile=$GENERATED_CONFIG_FILES/config_update_${i}_${CHANNEL}_in_envelope.pb
./bin/configtxlator proto_encode --input $configUpdateEnvelopeJsonFile --type common.Envelope --output $configUpdateEnvelopePbFile
echo "DOne 6"

./bin/peer channel update -f $configUpdateEnvelopePbFile -c ${CHANNEL} -o $ORDERER --tls true --cafile $ORDERER_CA
echo "DOne 7"