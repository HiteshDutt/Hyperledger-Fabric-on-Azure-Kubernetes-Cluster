#!/bin/bash

. /var/hyperledger/scripts/utils.sh
. /var/hyperledger/scripts/globals.sh
. /var/hyperledger/scripts/generateCertificatesModule.sh 

rm -rf $CRYPTO_PATH
mkdir -p $CA_CRYPTO_PATH/{ca-admin,ca-server,tlsca-admin,tlsca-server}
rm -rf $FABRIC_MSP_PATH
mkdir -p $FABRIC_MSP_PATH

echo "#Scale Down All deployments in HLF namespace#"
executeKubectlWithRetry "kubectl -n ${nodesNamespace} scale deploy --replicas=0 --all" "Scale Down all deployment failed" "$fabricToolsScriptStartTime" "verifyResult"

if [ "$NODE_TYPE" = "orderer" ]; then
  ORG_CRYPTO_PATH="$CRYPTO_PATH/ordererOrganizations/$ORG_NAME/"
else
  ORG_CRYPTO_PATH="$CRYPTO_PATH/peerOrganizations/$ORG_NAME/"
fi

# ---------------------------------------------------
# Enroll fabric CA admin
# ---------------------------------------------------
export FABRIC_CA_CLIENT_HOME=$CA_CRYPTO_PATH/ca-admin
export FABRIC_CA_CLIENT_TLS_CERTFILES=/var/hyperledger/tls/rca.pem
# maximum retry attempt to connect to fabric-ca
MAX_RETRY_COUNT=10
for ((retryCount=1;retryCount<=$MAX_RETRY_COUNT;retryCount++));
do
  echo "Attempt $retryCount: Enrolling Fabric CA admin" $FABRIC_CA_CLIENT_HOME
  fabric-ca-client enroll -u https://$CA_ADMIN_NAME:$CA_ADMIN_PASSWORD@${CAServerName}:${CAServerPort}
  res=$?
  if [ $res -eq 0 ]
  then
    break
  fi
  sleep 30
done
verifyResult $res "Enrolling Fabric CA Admin Failed!" "$fabricToolsScriptStartTime"
logMessage "Info" "Enrolled Fabric CA Admin!" "$fabricToolsScriptStartTime"


# ---------------------------------------------------
# Enroll each node
# ---------------------------------------------------
for ((i=1;i<=$NODE_COUNT;i++));
do
  executeKubectlWithRetry "kubectl -n ${nodesNamespace} delete secret hlf${NODE_TYPE}${i}-idcert" "Deleteting ${NODE_TYPE}${i} Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
  if [ $res -ne 0 ]; then
    logMessage "Error" "Deleting ${NODE_TYPE}${i} Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime"
    exit 1
  fi

  executeKubectlWithRetry "kubectl -n ${nodesNamespace} delete secret hlf${NODE_TYPE}${i}-idkey" "Deleting ${NODE_TYPE}${i} Enrollement private key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
  if [ $res -ne 0 ]; then
    logMessage "Error" "Deleting ${NODE_TYPE}${i} Enrollement private key in secrets failed" "$fabricToolsScriptStartTime"
    exit 1
  fi
  enrollNode $NODE_TYPE $i
done

# ---------------------------------------------------
# Enroll admin user
# ---------------------------------------------------
executeKubectlWithRetry "kubectl -n ${adminNamespace} delete secret hlf-admin-idcert" "Deleting Admin user Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
if [ $res -ne 0 ]; then
  logMessage "Error" "Deleting Admin user Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime"
  exit 1
fi

executeKubectlWithRetry "kubectl -n ${adminNamespace} delete secret hlf-admin-idkey" "Deleting Admin user Enrollement Key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
if [ $res -ne 0 ]; then
  logMessage "Error" "Deleting Admin user Enrollement key in secrets failed" "$fabricToolsScriptStartTime"
  exit 1
fi
enrollAdminUser

# ---------------------------------------------------
# Org MSP
# ---------------------------------------------------
logMessage "Info" "Generate Organization MSP" "$fabricToolsScriptStartTime"
mkdir -p $ORG_CRYPTO_PATH/msp/{cacerts,tlscacerts,admincerts}

# cacerts --orderer
export FABRIC_CA_CLIENT_HOME=$CA_CRYPTO_PATH/ca-admin
export FABRIC_CA_CLIENT_MSPDIR=""
fabric-ca-client getcacert -u https://${CAServerName}:${CAServerPort} -M $ORG_CRYPTO_PATH/msp
res=$?
verifyResult $res "Fetching CA Certificates from Fabric CA failed!" "$fabricToolsScriptStartTime"

# AdminCerts --orderer
fabric-ca-client identity list
fabric-ca-client certificate list --id admin.$ORG_NAME --store $ORG_CRYPTO_PATH/msp/admincerts
res=$?
verifyResult $res "Fetching Admin user Certificates from Fabric CA Failed!" "$fabricToolsScriptStartTime"

# ---------------------------------------------------
# Enroll each node
# ---------------------------------------------------
for ((i=1;i<=$NODE_COUNT;i++));
do
    executeKubectlWithRetry "kubectl -n ${nodesNamespace} delete secret hlf${NODE_TYPE}${i}-tls-idcert" "Deleteting ${NODE_TYPE}${i} Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
    if [ $res -ne 0 ]; then
      logMessage "Error" "Deleting ${NODE_TYPE}${i} TLS Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime"
      exit 1
    fi

    executeKubectlWithRetry "kubectl -n ${nodesNamespace} delete secret hlf${NODE_TYPE}${i}-tls-idkey" "Deleting ${NODE_TYPE}${i} Enrollement private key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
    if [ $res -ne 0 ]; then
      logMessage "Error" "Deleting ${NODE_TYPE}${i} TLS Enrollement private key in secrets failed" "$fabricToolsScriptStartTime"
      exit 1
    fi
    enrollNodeTLS $NODE_TYPE $i
done

# ---------------------------------------------------
# Enroll admin user
# ---------------------------------------------------
executeKubectlWithRetry "kubectl -n ${adminNamespace} delete secret hlf-admin-tls-idcert" "Deleting Admin user Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
if [ $res -ne 0 ]; then
  logMessage "Error" "Deleting Admin user TLS Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime"
  exit 1
fi

executeKubectlWithRetry "kubectl -n ${adminNamespace} delete secret hlf-admin-tls-idkey" "Deleting Admin user Enrollement Key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
if [ $res -ne 0 ]; then
  logMessage "Error" "Deleting Admin user TLS Enrollement Private key in secrets failed" "$fabricToolsScriptStartTime"
  exit 1
fi
enrollAdminUserTLS

# fetch tlscacerts
export FABRIC_CA_CLIENT_HOME=$CA_CRYPTO_PATH/tlsca-admin
export FABRIC_CA_CLIENT_MSPDIR=""
fabric-ca-client getcacert -u https://${CAServerName}:${CAServerPort} -M $ORG_CRYPTO_PATH/msp --enrollment.profile tls
res=$?
verifyResult $res "Fetching TLSCA Certificates from Fabric CA failed!" "$fabricToolsScriptStartTime"

# Store certificates in secrets
TLSCA_CERT=$(ls $ORG_CRYPTO_PATH/msp/tlscacerts/*pem)
executeKubectlWithRetry "kubectl -n ${caNamespace} delete secret hlf-tlsca-idcert" "Deleting TLSCA Certificates in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"
executeKubectlWithRetry "kubectl -n ${caNamespace} create secret generic hlf-tlsca-idcert --from-file=ca.crt=$TLSCA_CERT" "Storing TLSCA Certificates in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"
logMessage "Info" "Stored Org TLSCA certificates in kubernetes store!" "$fabricToolsScriptStartTime"

# delete keystore and signcerts empty dir
rm -rf $ORG_CRYPTO_PATH/msp/{keystore,signcerts,user}
# Done with generating certificates. Delete Fabric CA admin certificates
rm -rf $CA_CRYPTO_PATH

executeKubectlWithRetry "kubectl -n ${adminNamespace} delete secret hlf-ca-idcert" "Deleting CA Certificates in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"
exportSecret hlf-ca-idcert ${caNamespace} ${adminNamespace} ${scriptStartTime}

executeKubectlWithRetry "kubectl -n ${adminNamespace} delete secret hlf-tlsca-idcert" "Deleting TLSCA Certificates in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"
exportSecret hlf-tlsca-idcert ${caNamespace} ${adminNamespace} ${scriptStartTime}

executeKubectlWithRetry "kubectl -n ${nodesNamespace} delete secret hlf-ca-idcert" "Deleting CA Certificates in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"
exportSecret hlf-ca-idcert ${caNamespace} ${nodesNamespace} ${scriptStartTime}

executeKubectlWithRetry "kubectl -n ${nodesNamespace} delete secret hlf-tlsca-idcert" "Deleting TLS CA Certificates in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"
exportSecret hlf-tlsca-idcert ${caNamespace} ${nodesNamespace} ${scriptStartTime}

executeKubectlWithRetry "kubectl -n ${nodesNamespace} delete secret hlf-admin-idcert" "Deleting ADMIN Certificates in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"
exportSecret hlf-admin-idcert ${adminNamespace} ${nodesNamespace} ${scriptStartTime}

executeKubectlWithRetry "kubectl -n ${toolsNamespace} delete secret fabric-ca-server-config" "Deleting fabric-ca-server-config in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"

executeKubectlWithRetry "kubectl -n ${toolsNamespace} delete secret pg-ssl-rootcert" "Deleting pg-ssl-rootcert in kubernetes secrets failed!" "$fabricToolsScriptStartTime" "verifyResult"

echo "#Scale Up All deployments in HLF namespace#"
executeKubectlWithRetry "kubectl -n ${nodesNamespace} scale deploy --replicas=1 --all" "Scale Down all deployment failed" "$fabricToolsScriptStartTime" "verifyResult"