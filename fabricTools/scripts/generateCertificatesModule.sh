#!/bin/bash

. /var/hyperledger/scripts/utils.sh
. /var/hyperledger/scripts/globals.sh

ORG_NAME="${HLF_ORG_NAME}"
NODE_COUNT="${HLF_NODE_COUNT}"
DOMAIN_NAME="${HLF_DOMAIN_NAME}"
NODE_TYPE="${HLF_NODE_TYPE}"
CRYPTO_PATH=/tmp/crypto-config
FABRIC_MSP_PATH=/tmp/FabricMSP
CA_ADMIN_NAME=$(cat $CA_ADMIN_USERNAME_FILE)
CA_ADMIN_NAME=$(cat $CA_ADMIN_USERNAME_FILE)
CA_ADMIN_PASSWORD=$(cat $CA_ADMIN_PASSWORD_FILE)
CA_CRYPTO_PATH="$CRYPTO_PATH/fabca/$ORG_NAME"
fabricToolsScriptStartTime="$(date -u +%s)"

function registerNode() {
  nodeType=$1
  nodeNum=$2
  
  if [ "$nodeType" = "orderer" ]; then
    fabric-ca-client register --id.name "orderer$nodeNum.$ORG_NAME" --id.secret ${CA_ADMIN_PASSWORD} --id.type orderer -u https://$CAServerName:$CAServerPort > /dev/null
  else
    fabric-ca-client register --id.name "peer$nodeNum.$ORG_NAME" --id.secret ${CA_ADMIN_PASSWORD} --id.type peer -u https://$CAServerName:$CAServerPort > /dev/null
  fi
  res=$?
  verifyResult $res "Registering ${nodeType}${nodeNum} failed!" "$fabricToolsScriptStartTime"
  logMessage "Info" "Registered ${nodeType}${nodeNum} for ${ORG_NAME} org" "$fabricToolsScriptStartTime"
}


function registerAdminUser() {
  fabric-ca-client register --id.name admin.$ORG_NAME --id.secret ${CA_ADMIN_PASSWORD} --id.type admin --id.attrs "hf.Registrar.Roles=*,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://$CAServerName:$CAServerPort > /dev/null
  res=$?
  verifyResult $res "Registering admin user for ${ORG_NAME} org failed!" "$fabricToolsScriptStartTime"
  logMessage "Info" "Registered admin user for ${ORG_NAME} org" "$fabricToolsScriptStartTime"
}

function registerAdminUserTls() {
  fabric-ca-client register --id.name admin.tls.$ORG_NAME --id.secret ${CA_ADMIN_PASSWORD} --id.type admin --id.attrs "hf.Registrar.Roles=*,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://$CAServerName:$CAServerPort > /dev/null
  res=$?
  verifyResult $res "Registering admin user TLS for ${ORG_NAME} org failed!" "$fabricToolsScriptStartTime"
  logMessage "Info" "Registered admin user TLS for ${ORG_NAME} org" "$fabricToolsScriptStartTime"
}

function enrollNode() {
  nodeType=$1
  nodeNum=$2
  
  logMessage "Info" "Generating enrollement certificates for ${nodeType}${nodeNum}" "$fabricToolsScriptStartTime"

  rm -rf $FABRIC_MSP_PATH/*
  export FABRIC_CA_CLIENT_MSPDIR=$FABRIC_MSP_PATH

  fabric-ca-client enroll -u https://${nodeType}${nodeNum}.${ORG_NAME}:${CA_ADMIN_PASSWORD}@$CAServerName:$CAServerPort  --csr.names "O=$ORG_NAME"
  res=$?
  if [ $res -ne 0 ]; then
    logMessage "Error" "Generating enrollement certificate for ${nodeType}${nodeNum} failed" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
    exit 1
  fi

  # Store certificates in secrets
  NODE_CERT=$(ls $FABRIC_MSP_PATH/signcerts/*pem)
  executeKubectlWithRetry "kubectl -n ${nodesNamespace} create secret generic hlf${nodeType}${nodeNum}-idcert --from-file=cert.pem=$NODE_CERT" "Storing ${nodeType}${nodeNum} Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
  if [ $res -ne 0 ]; then
    logMessage "Error" "Storing ${nodeType}${nodeNum} Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
    exit 1
  fi

  # Store key in secrets
  NODE_KEY=$(ls $FABRIC_MSP_PATH/keystore/*_sk)
  executeKubectlWithRetry "kubectl -n ${nodesNamespace} create secret generic hlf${nodeType}${nodeNum}-idkey --from-file=key.pem=$NODE_KEY" "Storing ${nodeType}${nodeNum} Enrollement private key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
  if [ $res -ne 0 ]; then
    logMessage "Error" "Storing ${nodeType}${nodeNum} Enrollement private key in secrets failed" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
    exit 1
  fi

  logMessage "Info" "Generated enrollement certificate for ${nodeType}${nodeNum}" "$fabricToolsScriptStartTime"
 
  # Delete certificates from $FABRIC_MSP_PATH
  rm -rf $FABRIC_MSP_PATH/*
}

function enrollAdminUser() {
    rm -rf $FABRIC_MSP_PATH/*
    export FABRIC_CA_CLIENT_MSPDIR=$FABRIC_MSP_PATH
    fabric-ca-client enroll -u https://admin.$ORG_NAME:${CA_ADMIN_PASSWORD}@$CAServerName:$CAServerPort --csr.names "O=$ORG_NAME"
    res=$?
    if [ $res -ne 0 ]; then
      logMessage "Error" "Generating enrollement certificate for admin user failed" "$fabricToolsScriptStartTime"
      rm -rf $FABRIC_MSP_PATH/*
      exit 1
    fi
    
    # Store certificates in secrets
    ADMIN_CERT=$(ls $FABRIC_MSP_PATH/signcerts/*pem)
    executeKubectlWithRetry "kubectl -n ${adminNamespace} create secret generic hlf-admin-idcert --from-file=cert.pem=$ADMIN_CERT" "Storing Admin user Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
    if [ $res -ne 0 ]; then
      logMessage "Error" "Storing Admin user Enrollement certificate in secrets failed" "$fabricToolsScriptStartTime"
      rm -rf $FABRIC_MSP_PATH/*
      exit 1
    fi
    
    # Store key in secrets
    ADMIN_KEY=$(ls $FABRIC_MSP_PATH/keystore/*_sk)
    executeKubectlWithRetry "kubectl -n ${adminNamespace} create secret generic hlf-admin-idkey --from-file=key.pem=$ADMIN_KEY" "Storing Admin user Enrollement private key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
    if [ $res -ne 0 ]; then
      logMessage "Error" "Storing Admin user Enrollement private key in secrets failed" "$fabricToolsScriptStartTime"
      rm -rf $FABRIC_MSP_PATH/*
      exit 1
    fi

    logMessage "Info" "Generated enrollement certificate for admin user" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
}

function enrollAdminUserTLS() {
    rm -rf $FABRIC_MSP_PATH/*
    export FABRIC_CA_CLIENT_MSPDIR=$FABRIC_MSP_PATH
    fabric-ca-client enroll -u https://admin.tls.$ORG_NAME:${CA_ADMIN_PASSWORD}@$CAServerName:$CAServerPort --csr.names "O=$ORG_NAME" --enrollment.profile tls
    res=$?
    if [ $res -ne 0 ]; then
      logMessage "Error" "Generating TLS certificate for admin user failed" "$fabricToolsScriptStartTime"
      rm -rf $FABRIC_MSP_PATH/*
      exit 1
    fi

    # Store certificates in secrets
    ADMIN_CERT=$(ls $FABRIC_MSP_PATH/signcerts/*pem)
    executeKubectlWithRetry "kubectl -n ${adminNamespace} create secret generic hlf-admin-tls-idcert --from-file=cert.pem=$ADMIN_CERT" "Storing Admin user TLS certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
    if [ $res -ne 0 ]; then
      logMessage "Error" "Storing Admin user TLS certificate in secrets failed" "$fabricToolsScriptStartTime"
      rm -rf $FABRIC_MSP_PATH/*
      exit 1
    fi

    # Store key in secrets
    ADMIN_KEY=$(ls $FABRIC_MSP_PATH/keystore/*_sk)
    executeKubectlWithRetry "kubectl -n ${adminNamespace} create secret generic hlf-admin-tls-idkey --from-file=key.pem=$ADMIN_KEY" "Storing Admin user TLS private key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
    if [ $res -ne 0 ]; then
      logMessage "Error" "Storing Admin user TLS private key in secrets failed" "$fabricToolsScriptStartTime"
      rm -rf $FABRIC_MSP_PATH/*
      exit 1
    fi

    logMessage "Info" "Generated TLS certificate for admin user" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
}

function enrollNodeTLS() {
  nodeType=$1
  nodeNum=$2
 
  logMessage "Info" "Generating TLS certifiate for ${nodeType}${nodeNum}" "$fabricToolsScriptStartTime"

  rm -rf $FABRIC_MSP_PATH/*
  export FABRIC_CA_CLIENT_MSPDIR=$FABRIC_MSP_PATH
  fabric-ca-client enroll -u https://${nodeType}${nodeNum}.${ORG_NAME}:${CA_ADMIN_PASSWORD}@$CAServerName:$CAServerPort --enrollment.profile tls --csr.hosts "${nodeType}$i,${nodeType}$i.$DOMAIN_NAME"
  res=$?
  if [ $res -ne 0 ]; then
    logMessage "Error" "Generating TLS certificate for ${nodeType}${nodeNum} failed" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
    exit 1
  fi

  # Store certificates in secrets
  NODE_TLS_CERT=$(ls $FABRIC_MSP_PATH/signcerts/*pem)
  executeKubectlWithRetry "kubectl -n ${nodesNamespace} create secret generic hlf${nodeType}${nodeNum}-tls-idcert --from-file=server.crt=$NODE_TLS_CERT" "Storing ${nodeType}${nodeNum} TLS certificate in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
  if [ $res -ne 0 ]; then
    logMessage "Error" "Storing ${nodeType}${nodeNum} TLS certificate in secrets failed" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
    exit 1
  fi

  # Store key in secrets
  NODE_TLS_KEY=$(ls $FABRIC_MSP_PATH/keystore/*_sk)
  executeKubectlWithRetry "kubectl -n ${nodesNamespace} create secret generic hlf${nodeType}${nodeNum}-tls-idkey --from-file=server.key=$NODE_TLS_KEY" "Storing ${nodeType}${nodeNum} TLS private key in secrets failed" "$fabricToolsScriptStartTime" "no-verifyResult"
  if [ $res -ne 0 ]; then
    logMessage "Error" "Storing ${nodeType}${nodeNum} TLS private key in secrets failed" "$fabricToolsScriptStartTime"
    rm -rf $FABRIC_MSP_PATH/*
    exit 1
  fi

  if [ "$nodeType" == "orderer" ]; then
    #store public key in folder for genesis block generation
    mkdir -p $ORG_CRYPTO_PATH/orderers/orderer${nodeNum}/tls
    cp $FABRIC_MSP_PATH/signcerts/*.pem $ORG_CRYPTO_PATH/orderers/orderer${nodeNum}/tls/server.crt
  fi

  logMessage "Info" "Generated TLS certificate for ${nodeType}${nodeNum}" "$fabricToolsScriptStartTime"
  rm -rf $FABRIC_MSP_PATH/*
}
