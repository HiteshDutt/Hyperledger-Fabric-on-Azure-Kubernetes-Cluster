storageAccountName=${1}
containerName=${2}
accountKey=${3}

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $BASEDIR
cd ../out
BASEDIR=$(pwd)

az storage blob upload --account-name $storageAccountName --container-name $containerName --file $BASEDIR/hlf-marketplace.zip --name hlf-marketplace.zip --account-key $accountKey

az storage blob upload --account-name $storageAccountName --container-name $containerName --file $BASEDIR/artifacts/funcNodeJS.zip --name artifacts/funcNodeJS.zip --account-key $accountKey

az storage blob upload --account-name $storageAccountName --container-name $containerName --file $BASEDIR/nestedtemplates/publicIpTemplate.json --name nestedtemplates/publicIpTemplate.json --account-key $accountKey

az storage blob upload --account-name $storageAccountName --container-name $containerName --file $BASEDIR/mainTemplate.json --name mainTemplate.json --account-key $accountKey
