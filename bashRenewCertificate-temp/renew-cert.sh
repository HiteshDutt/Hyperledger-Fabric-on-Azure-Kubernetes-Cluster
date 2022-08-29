scriptStartTime="$(date -u +%s)"
toolsNamespace="tools"
caNamespace="ca"
statusNamespace="metadata"
nodesNamespace="hlf"
adminNamespace="hlf-admin"
nginxNamespace="nginx"
renewPodFilePath=./renew_tools_pod.json
HLF_STATIC_IP=${1}
HLF_NODE_TYPE=${2}
HLF_NODE_COUNT=${3}
HLF_ORG_NAME=${4}
HLF_BACKEND_DB=${5}
HLF_DOMAIN_NAME=${6}

executeKubectlWithRetry() {
  count=1
  maxRetries=3
  retryInterval=3
  logStartTime=$3
  while [ $count -le $maxRetries ]
  do	  
    eval $1
    res=$?
    if [ $res -eq 0 ] 
    then
      break
    fi
    logMessage "Warning" "Attempt $count: $2" "$logStartTime"
    if [ "$4" = "verifyResult" ] && [ $count -eq $maxRetries ]; then
      verifyResult $res "$2" "$logStartTime"
    fi
    if [  $count -lt $maxRetries ]; then
      sleep $retryInterval
    fi
    ((count++))
  done
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    logMessage "Error" "$2" "$3"  
    exit 1
  fi
}

logMessage() {
  logCurrentTime="$(date -u +%s)"
  date=$(date -u)  
  logStartTime=$3
  logElapsedTime=$(($logCurrentTime - $logStartTime))
  if [ "$1" = "Error" ]; then
    echo "============== [$date] HLF SETUP ERROR !!! "$2" !!! ERROR CODE: "$res" !!! Time elapsed: $logElapsedTime seconds ==============="
    echo
  elif [ "$1" = "Warning" ]; then
    echo "==== [$date] HLF SETUP WARNING !!! "$2" !!! Time elapsed: $logElapsedTime seconds ===="                                                  
    echo
  elif [ "$1" = "Info" ]; then
    echo
    echo "=========== [$date] HLF SETUP INFO !!! $2 !!! Time elapsed: $logElapsedTime seconds ==========="
    echo
  fi
}

exportSecret() {
    secretName=$1
    sourceNamespace=$2
    targetNamespace=$3
    logStartTime=$4

    executeKubectlWithRetry "kubectl -n ${sourceNamespace} get secret ${secretName} -o yaml | sed \"s/namespace: ${sourceNamespace}/namespace: ${targetNamespace}/\" | kubectl apply -n ${targetNamespace} -f -" "Failed to create secret '$secretName'!" "$logStartTime" "verifyResult"
}

echo "# COPY REQUIRED SECRETS TO TOOLS NAMESPACE #"

exportSecret fabric-ca-server-config ${caNamespace} ${toolsNamespace} ${scriptStartTime}
exportSecret pg-ssl-rootcert ${caNamespace} ${toolsNamespace} ${scriptStartTime}

echo '# EDIT RENEW JSON POD FILE #'
HLFIPADDESSCHANGE=$(jq --arg match "HLF_STATIC_IP" --arg replace "$HLF_STATIC_IP" '.spec.containers[].env |= map(if .name == $match then (.value=$replace) else . end)' < $renewPodFilePath)
echo "$HLFIPADDESSCHANGE" > $renewPodFilePath
HLFNODETYPECHANGE=$(jq --arg match "HLF_NODE_TYPE" --arg replace "$HLF_NODE_TYPE" '.spec.containers[].env |= map(if .name == $match then (.value=$replace) else . end)' < $renewPodFilePath)
echo "$HLFNODETYPECHANGE" > $renewPodFilePath
HLFNODECOUNTCHANGE=$(jq --arg match "HLF_NODE_COUNT" --arg replace "$HLF_NODE_COUNT" '.spec.containers[].env |= map(if .name == $match then (.value=$replace) else . end)' < $renewPodFilePath)
echo "$HLFNODECOUNTCHANGE" > $renewPodFilePath
HLFORGNAMECHANGE=$(jq --arg match "HLF_ORG_NAME" --arg replace "$HLF_ORG_NAME" '.spec.containers[].env |= map(if .name == $match then (.value=$replace) else . end)' < $renewPodFilePath)
echo "$HLFORGNAMECHANGE" > $renewPodFilePath
HLFBACKENDDBCHANGE=$(jq --arg match "HLF_BACKEND_DB" --arg replace "$HLF_BACKEND_DB" '.spec.containers[].env |= map(if .name == $match then (.value=$replace) else . end)' < $renewPodFilePath)
echo "$HLFBACKENDDBCHANGE" > $renewPodFilePath
HLFDOMAINNAMECHANGE=$(jq --arg match "HLF_DOMAIN_NAME" --arg replace "$HLF_DOMAIN_NAME" '.spec.containers[].env |= map(if .name == $match then (.value=$replace) else . end)' < $renewPodFilePath)
echo "$HLFDOMAINNAMECHANGE" > $renewPodFilePath
echo # START EXECUTION #
executeKubectlWithRetry "kubectl -n ${toolsNamespace} apply -f $renewPodFilePath" "Starting Renew Pod failed!" "$fabricToolsScriptStartTime" "verifyResult"