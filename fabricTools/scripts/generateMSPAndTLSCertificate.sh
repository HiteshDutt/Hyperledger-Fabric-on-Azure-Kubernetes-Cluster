. ./renewGlobals.sh

echo "======================= GET INFORMATION  =============================="
#TYPE=${HLF_NODE_TYPE}
TYPE=$1
#CHANNEL_NAME=${ALL_CHANNELS_CSV}
CHANNEL_NAME=$2
ORDERER_ORG_NAME=$3
ORDERER_ORG_DOMAIN=$4
CURRENT_LOCATION=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "======================== GET CERTIFICATES =================================="

echo
echo "Enroll the CA admin"
echo
ORG_NEW_CRYPTOCONFIG=${CRYPTO_CONFIG_NEW}/$TYPE/$ORG_NAME
echo $ORG_NEW_CRYPTOCONFIG
ORG_CRYPTOCONFIG=${CRYPTO_CONFIG}/$TYPE/$ORG_NAME
TLS_CERT_PATH=${ORG_CRYPTOCONFIG}/msp/cacerts/rca.pem
mkdir -p $ORG_NEW_CRYPTOCONFIG
export FABRIC_CA_CLIENT_HOME=$ORG_NEW_CRYPTOCONFIG

./bin/fabric-ca-client enroll -u https://$CA_USER:$CA_PASSWORD@${CAServerName}:${CAServerPort} --tls.certfiles ${TLS_CERT_PATH}

 i=1
while [ $i -le $NODE_COUNT ]
do
        echo "========================== SCALE POD DOWN ${TYPE} ${i} ================================"
        kubectl -n ${nodeNamespace} scale deploy ${TYPE}${i} --replicas=0

        echo "========================== GET NODE CERTIFICATES ${TYPE} ${ORG_NAME} ${i}================================="
        echo
        echo "## Generate the ${TYPE} msp for ${ORG_NAME} ${i}"
        echo
        nodeCertificateLocation=${ORG_NEW_CRYPTOCONFIG}/${TYPE}${i}.${ORG_NAME}
        mkdir -p $nodeCertificateLocation
        ./bin/fabric-ca-client enroll -u https://${TYPE}${i}.${ORG_NAME}:${CA_PASSWORD}@$CAServerName:$CAServerPort --csr.names "O=$ORG_NAME" -M ${nodeCertificateLocation} --tls.certfiles ${TLS_CERT_PATH}

        NODE_CERT=$(ls $nodeCertificateLocation/signcerts/*pem)
        kubectl -n ${nodeNamespace} delete secret hlf${TYPE}${i}-idcert
        kubectl -n ${nodeNamespace} create secret generic hlf${TYPE}${i}-idcert --from-file=cert.pem=$NODE_CERT
        NODE_KEY=$(ls $nodeCertificateLocation/keystore/*_sk)
        echo $NODE_KEY
        kubectl -n ${nodeNamespace} delete secret hlf${TYPE}${i}-idkey
        kubectl -n ${nodeNamespace} create secret generic hlf${TYPE}${i}-idkey --from-file=key.pem=$NODE_KEY

        
        echo "========================== SCALE POD UP ${TYPE} ${i} ================================"
        kubectl -n ${nodeNamespace} scale deploy ${TYPE}${i} --replicas=1
        echo "========================== wait for ${TYPE} ${i} to be up ==============================="
        kubectl wait deployment -n ${nodeNamespace} ${TYPE}${i} --for condition=Available=True --timeout=200s

        i=$(($i+1))
done

echo "===============================Wait for 120s====================================="
sleep 120

echo "======================== TLS CERTFICATE SECTION =========================="
i=1
while [ $i -le $NODE_COUNT ]
do
        echo
        echo "## Generate the ${TYPE} tls certificates for ${ORG_NAME} ${i}"
        echo
        nodeTlsCertificateLocation=${ORG_NEW_CRYPTOCONFIG}/${TYPE}${i}.${ORG_NAME}/tls
        ./bin/fabric-ca-client enroll -u https://${TYPE}${i}.${ORG_NAME}:${CA_PASSWORD}@$CAServerName:$CAServerPort --csr.hosts "${TYPE}$i,${TYPE}$i.$DOMAIN_NAME" -M ${nodeTlsCertificateLocation} --enrollment.profile tls --tls.certfiles ${TLS_CERT_PATH}
        
        cp $nodeTlsCertificateLocation/tlscacerts/* $nodeTlsCertificateLocation/ca.crt
        cp $nodeTlsCertificateLocation/signcerts/* $nodeTlsCertificateLocation/server.crt
        cp $nodeTlsCertificateLocation/keystore/* $nodeTlsCertificateLocation/server.key

        mkdir -p ${ORG_NEW_CRYPTOCONFIG}/${TYPE}${i}.${ORG_NAME}/msp/tlscacerts
        cp ${ORG_NEW_CRYPTOCONFIG}/${TYPE}${i}.${ORG_NAME}/tls/tlscacerts/* ${ORG_NEW_CRYPTOCONFIG}/${TYPE}${i}.${ORG_NAME}/msp/tlscacerts/tlsca.$ORG_NAME-cert.pem
        ordererType="Orderer"
        if [ "${TYPE,,}" = "${ordererType,,}" ]; then
                echo "================================= STEP ONLY FOR ORDERER ================================="
                IFS=',' read -r -a array <<< $CHANNEL_NAME
                for channel in "${array[@]}"
                do
                        echo "=============== Making Transaction for CHANNEL ${channel} - ${TYPE} ${i} ========================="
                        ./ordererTransaction.sh $channel $ORG_NAME $DOMAIN_NAME $i $nodeTlsCertificateLocation/server.crt
                done 
        fi
        
        NODE_TLS_CERT=$(ls $nodeTlsCertificateLocation/signcerts/*pem)
        kubectl -n ${nodeNamespace} delete secret hlf${TYPE}${i}-tls-idcert
        kubectl -n ${nodeNamespace} create secret generic hlf${TYPE}${i}-tls-idcert --from-file=server.crt=$NODE_TLS_CERT
        NODE_TLS_KEY=$(ls $nodeTlsCertificateLocation/keystore/*_sk)
        kubectl -n ${nodeNamespace} delete secret hlf${TYPE}${i}-tls-idkey 
        kubectl -n ${nodeNamespace} create secret generic hlf${TYPE}${i}-tls-idkey --from-file=server.key=$NODE_TLS_KEY

         echo "========================== SCALE POD DOWN ${TYPE} ${i} ================================"
        kubectl -n ${nodeNamespace} scale deploy ${TYPE}${i} --replicas=0

         echo "========================== SCALE POD UP ${TYPE} ${i} ================================"
        kubectl -n ${nodeNamespace} scale deploy ${TYPE}${i} --replicas=1
        
        echo "========================== wait for ${TYPE} ${i} to be up ==============================="
        kubectl wait deployment -n ${nodeNamespace} ${TYPE}${i} --for condition=Available=True --timeout=200s
        i=$(($i+1))
        if [ "${TYPE,,}" = "${ordererType,,}" ]; then
                echo "======================== WAIT FOR 120s for consensus to begin =============================="
                sleep 120
        fi
done

#===============================================ADMIN CERTIFICATE SECTION================================#

echo "======================== WAIT FOR 120 s =============================="
sleep 120

echo
echo "## Generate the admin msp ${ORG_NAME}"
echo

adminCertificateLocation=${ORG_NEW_CRYPTOCONFIG}/users/admin@$ORG_NAME
./bin/fabric-ca-client enroll -u https://admin.$ORG_NAME:${CA_PASSWORD}@$CAServerName:$CAServerPort -M ${adminCertificateLocation} --csr.names "O=$ORG_NAME" --tls.certfiles ${TLS_CERT_PATH}
ADMIN_CERT=$(ls $adminCertificateLocation/signcerts/*pem)
echo $ADMIN_CERT
IFS=',' read -r -a array <<< $CHANNEL_NAME
for channel in "${array[@]}"
do
        echo "=============== Making Admin CERTIFICATE UPDATE for CHANNEL ${channel} - ${TYPE} ${i} ========================="
        ./adminTransaction.sh $channel $ORG_NAME $DOMAIN_NAME $ORDERER_ORG_NAME $ORDERER_ORG_DOMAIN $TYPE $ADMIN_CERT
done

kubectl -n ${adminNamespace} delete secret hlf-admin-idcert
kubectl -n ${adminNamespace} create secret generic hlf-admin-idcert --from-file=cert.pem=$ADMIN_CERT
verifyResult $? "FAILED - CREATING HLF ADMIN ID CERT in ${adminNamespace}" " "   
kubectl -n ${nodeNamespace} delete secret hlf-admin-idcert
kubectl -n ${nodeNamespace} create secret generic hlf-admin-idcert --from-file=cert.pem=$ADMIN_CERT
verifyResult $? "FAILED - CREATING HLF ADMIN ID CERT in ${nodeNamespace}" " "
ADMIN_KEY=$(ls $adminCertificateLocation/keystore/*_sk)
kubectl -n ${adminNamespace} delete secret hlf-admin-idkey
kubectl -n ${adminNamespace} create secret generic hlf-admin-idkey --from-file=key.pem=$ADMIN_KEY
verifyResult $? "FAILED - CREATING HLF ADMIN ID CERT in ${nodeNamespace}" " "

echo "========================== SCALE POD DOWN ${TYPE} ${i} ================================"
kubectl -n ${nodeNamespace} scale deploy --replicas=0 --all

echo "========================== SCALE POD UP ${TYPE} ${i} ================================"
kubectl -n ${nodeNamespace} scale deploy --replicas=1 --all


