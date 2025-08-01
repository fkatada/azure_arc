@description('Azure service principal client id')
param spnClientId string

@description('Azure service principal client secret')
@secure()
param spnClientSecret string

@description('Azure AD tenant id for your service principal')
param spnTenantId string

@description('Location for all resources')
param location string = resourceGroup().location

@maxLength(5)
@description('Random GUID')
param namingGuid string = toLower(substring(newGuid(), 0, 5))

@description('Username for Windows account')
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
param sshRSAPublicKey string

@description('Name for your log analytics workspace')
param logAnalyticsWorkspaceName string = 'Ag-Workspace-${namingGuid}'

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('User github account where they have forked the repo https://github.com/azure/jumpstart-apps')
@minLength(1)
param githubUser string

@description('GitHub Personal access token for the user account')
@minLength(1)
@secure()
param githubPAT string

@description('Name of the Cloud VNet')
param virtualNetworkNameCloud string = 'Ag-Vnet-Prod'

@description('Name of the Staging AKS subnet in the cloud virtual network')
param subnetNameCloudAksStaging string = 'Ag-Subnet-Staging'

@description('Name of the inner-loop AKS subnet in the cloud virtual network')
param subnetNameCloudAksInnerLoop string = 'Ag-Subnet-InnerLoop'

@description('The name of the Staging Kubernetes cluster resource')
param aksStagingClusterName string = 'Ag-AKS-Staging'

@description('The name of the IotHub')
param iotHubName string = 'Ag-IotHub-${namingGuid}'

@description('The name of the Cosmos DB account')
param accountName string = 'agcosmos${namingGuid}'

@description('The name of the Azure Data Explorer cluster')
param adxClusterName string = 'agadx${namingGuid}'

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string = 'Orders'

@minLength(5)
@maxLength(50)
@description('Name of the Azure Container Registry')
param acrName string = 'agacr${namingGuid}'

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Enable automatic logon into Virtual Machine')
param vmAutologon bool = true

@description('Name of the NAT Gateway')
param natGatewayName string = 'Ag-NatGateway-${namingGuid}'

@description('The agora scenario to be deployed')
param scenario string = 'contoso_supermarket'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_jumpstart_ag/'

var customerUsageAttributionDeploymentName = '7d736ea9-23b4-4134-95a1-560ab7196aae'

module customerUsageAttribution 'mgmt/customerUsageAttribution.bicep' = {
  name: 'pid-${customerUsageAttributionDeploymentName}'
  params: {
  }
}

module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
  }
}

module networkDeployment 'mgmt/network.bicep' = {
  name: 'networkDeployment'
  params: {
    virtualNetworkNameCloud: virtualNetworkNameCloud
    subnetNameCloudAksStaging: subnetNameCloudAksStaging
    subnetNameCloudAksInnerLoop: subnetNameCloudAksInnerLoop
    deployBastion: deployBastion
    location: location
    natGatewayName: natGatewayName
  }
}

module storageAccountDeployment 'mgmt/storageAccount.bicep' = {
  name: 'storageAccountDeployment'
  params: {
    location: location
  }
}

module kubernetesDeployment 'kubernetes/aks.bicep' = {
  name: 'kubernetesDeployment'
  params: {
    aksStagingClusterName: aksStagingClusterName
    virtualNetworkNameCloud: networkDeployment.outputs.virtualNetworkNameCloud
    aksSubnetNameStaging: subnetNameCloudAksStaging
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    location: location
    sshRSAPublicKey: sshRSAPublicKey
    acrName: acrName
  }
}

module clientVmDeployment 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  params: {
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    workspaceName: logAnalyticsWorkspaceName
    storageAccountName: storageAccountDeployment.outputs.storageAccountName
    templateBaseUrl: templateBaseUrl
    deployBastion: deployBastion
    githubAccount: githubAccount
    githubBranch: githubBranch
    githubUser: githubUser
    githubPAT: githubPAT
    location: location
    subnetId: networkDeployment.outputs.innerLoopSubnetId
    aksStagingClusterName: aksStagingClusterName
    iotHubHostName: iotHubDeployment.outputs.iotHubHostName
    cosmosDBName: accountName
    cosmosDBEndpoint: cosmosDBDeployment.outputs.cosmosDBEndpoint
    acrName: acrName
    rdpPort: rdpPort
    adxClusterName: adxClusterName
    namingGuid: namingGuid
    scenario: scenario
    vmAutologon: vmAutologon
  }
}

module iotHubDeployment 'data/iotHub.bicep' = {
  name: 'iotHubDeployment'
  params: {
    location: location
    iotHubName: iotHubName
  }
}

module adxDeployment 'data/dataExplorer.bicep' = {
  name: 'adxDeployment'
  params: {
    location: location
    adxClusterName: adxClusterName
    iotHubId: iotHubDeployment.outputs.iotHubId
    iotHubConsumerGroup: iotHubDeployment.outputs.iotHubConsumerGroup
    cosmosDBAccountName: accountName
    posOrdersDBName: posOrdersDBName
  }
}

module cosmosDBDeployment 'data/cosmosDB.bicep' = {
  name: 'cosmosDBDeployment'
  params: {
    location: location
    accountName: accountName
    posOrdersDBName: posOrdersDBName
  }
}
