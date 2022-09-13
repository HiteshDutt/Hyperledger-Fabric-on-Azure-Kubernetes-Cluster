. ./renewGlobals.sh

channel=$1
ORDERER_ORG_NAME=$2
ORDERER_DNS=$3
i=$4
export ORDERER_NEW_TLS_FILE=$5
echo "#=========================================================RENEW ${ORDERER_ORG_NAME} ORDERER $i TLS CERTIFICATE===================================#"
CURRENT_LOCATION=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ $CERT_LOCATION == "" ]];then
    CERT_LOCATION="$CURRENT_LOCATION/cryptoconfig"
fi
export FABRIC_CFG_PATH="$CURRENT_LOCATION";
ORDERER="orderer$i.$ORDERER_DNS:443"
ORDERER_CA="$CERT_LOCATION/orderer/$ORDERER_ORG_NAME/orderer$i.$ORDERER_ORG_NAME/msp/tlscacerts/ca.crt"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=$ORDERER_ORG_NAME
export CORE_PEER_TLS_ROOTCERT_FILE=$CERT_LOCATION/$ORDERER_ORG_NAME/$orgName/orderer$i.$ORDERER_ORG_NAME/msp/tlscacerts/ca.crt
export CORE_PEER_MSPCONFIGPATH=$CERT_LOCATION/orderer/$ORDERER_ORG_NAME/msp
export CORE_PEER_ADDRESS="orderer$i.$ORDERER_DNS:443"
echo "#=========================================================Getting ${channel} config block=========================================#"
mkdir -p $GENERATED_CONFIG_FILES
pbFileName=$GENERATED_CONFIG_FILES/config_block_orderer$i$channel.pb
./bin/peer channel fetch config $pbFileName -o $ORDERER -c $channel --tls --cafile "$ORDERER_CA"
configFileName=$GENERATED_CONFIG_FILES/config$i$channel.json
./bin/configtxlator proto_decode --input $pbFileName --type common.Block | jq .data.data[0].payload.data.config >$configFileName
modifiedFileName=$GENERATED_CONFIG_FILES/modified_config$i$channel.json
modifiedFileName2=$GENERATED_CONFIG_FILES/modified_config$i${channel}2.json
cp $configFileName $modifiedFileName

echo "## Encode Orderer$i"
base64Cert=$(cat $ORDERER_NEW_TLS_FILE | base64 -w 0)
cat $modifiedFileName | jq --arg DomainName "orderer$i.$ORDERER_DNS" --arg Base64Cert $base64Cert '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters = (.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters | map(if .host == $DomainName then . + {"client_tls_cert":$Base64Cert, "server_tls_cert":$Base64Cert} else . end))' > $modifiedFileName2

configPbFile=$GENERATED_CONFIG_FILES/config$i$channel.pb
./bin/configtxlator proto_encode --input $configFileName --type common.Config --output $configPbFile
echo "DOne 1"
modifiedConfigPbFile=$GENERATED_CONFIG_FILES/modifiedconfig$i$channel.pb
./bin/configtxlator proto_encode --input $modifiedFileName2 --type common.Config --output $modifiedConfigPbFile
echo "DOne 2"
configUpdatePbFile=$GENERATED_CONFIG_FILES/config_update_$i_$channel.pb
./bin/configtxlator compute_update --channel_id $channel --original $configPbFile --updated $modifiedConfigPbFile --output $configUpdatePbFile
echo "DOne 3"
configUpdateJsonFile=$GENERATED_CONFIG_FILES/config_update_$i_$channel.json
./bin/configtxlator proto_decode --input $configUpdatePbFile --type common.ConfigUpdate --output $configUpdateJsonFile
echo "DOne 4"
configUpdateEnvelopeJsonFile=$GENERATED_CONFIG_FILES/config_update_${i}_${channel}_in_envelope.json
echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"$channel\", \"type\":2}},\"data\":{\"config_update\":"$(cat $configUpdateJsonFile)"}}}" | jq . >$configUpdateEnvelopeJsonFile
echo "DOne 5"
configUpdateEnvelopePbFile=$GENERATED_CONFIG_FILES/config_update_${i}_${channel}_in_envelope.pb
./bin/configtxlator proto_encode --input $configUpdateEnvelopeJsonFile --type common.Envelope --output $configUpdateEnvelopePbFile
echo "DOne 6"

./bin/peer channel update -f $configUpdateEnvelopePbFile -c $channel -o $ORDERER --tls true --cafile $ORDERER_CA
echo "DOne 7"