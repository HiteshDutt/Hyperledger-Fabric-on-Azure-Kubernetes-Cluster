#!/bin/bash
#read -p "Input resource group, please: " resourceGroup
#read -p "Input cloud type for china, value: china
. ./renewGlobals.sh
resourceGroup=$1
cloudType=$2
subscriptionId=$(az account show --query id -o tsv)
webAppRes=$(az resource list --resource-group $resourceGroup --resource-type "Microsoft.Web/sites" | grep "name")
webApp="${webAppRes//[\":,[:blank:]]}"
webAppName="${webApp//name}"
resourceId="/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$webAppName"

accessToken=$(az account get-access-token --query accessToken -o tsv)
functionName="ConfigManager"
listFunctionKeysUrl="https://management.chinacloudapi.cn$resourceId/functions/$functionName/listKeys?api-version=2018-02-01"

functionRes=$(curl -s -X POST $listFunctionKeysUrl -H "Content-Type: application/json" -H "Authorization: Bearer $accessToken" -H 'Content-Length: 0')

function="${functionRes//[\{\}\":]}"

functionDefaultKey="${function//default}"
if [ "${cloudType,,}" = "${CLOUD_TYPE_CHINA,,}" ]; then
    webAppExtension="chinacloudsites.cn"
else
    webAppExtension="azurewebsites.net"
fi
echo -e "\nhttps://$webAppName.$webAppExtension/api/{action}?code=$functionDefaultKey\n"