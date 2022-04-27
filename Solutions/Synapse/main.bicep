targetScope = 'subscription'

param location string = deployment().location
param aadTeamGroupObjectId string
param synapseResourceGroupName string
param synapseWorkspaceName string
param omsWorkspaceResourceGroup string
param omsWorkspaceName string
param storageAccountName string
param defaultStorageContainerName string
param pepResourceGroupName string
param pepVnetName string
param pepSubnetName string
param pepSubnetPrefix string
param pepDnsZoneResourceId string

var deployID = uniqueString(deployment().name, location)

resource vNet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
    scope: resourceGroup(pepResourceGroupName)
    name: pepVnetName
}

resource law 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
    scope: resourceGroup(omsWorkspaceResourceGroup)
    name: omsWorkspaceName
}

module synapseSubnet '../../Modules/Microsoft.Network/virtualNetworks/subnets/deploy.bicep' = {
    scope: resourceGroup(pepResourceGroupName)
    name: 'dep-${deployID}-synapse-subnet'
    params: {
        addressPrefix: pepSubnetPrefix
        name: pepSubnetName
        virtualNetworkName: vNet.name
    }
}

module synapseRG '../../Modules/Microsoft.Resources/resourceGroups/deploy.bicep' = {
    name: 'dep-${deployID}-synapse-rg'
    params: {
        name: synapseResourceGroupName
    }
}

module storageAccount '../../Modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
    scope: resourceGroup(synapseResourceGroupName)
    name: 'dep-${deployID}-storageAccount'
    params: {
        name: storageAccountName
        blobServices: {
            containers: [
                {
                    name: defaultStorageContainerName
                }
            ]
        }
        roleAssignments: [
            {
                roleDefinitionIdOrName: 'Storage Blob Data Reader'
                principalIds: [
                    aadTeamGroupObjectId
                    synapseWorkspace.outputs.resourceID
                ]
            }
        ]
    }
}

module synapseWorkspace '../../Modules/Microsoft.Synapse/workspaces/deploy.bicep' = {
    scope: resourceGroup(synapseResourceGroupName)
    name: 'dep-${deployID}-synapseWorkspace'
    params: {
        name: synapseWorkspaceName
        defaultDataLakeStorageAccountName: storageAccountName
        defaultDataLakeStorageFilesystem: 'synapsews'
        sqlAdministratorLogin: 'sqladminuser'
        roleAssignments: [
            {
                roleDefinitionIdOrName: 'Contributor'
                principalIds: [
                    aadTeamGroupObjectId
                ]
            }
        ]
        privateEndpoints: [
            {
                subnetResourceId: synapseSubnet.outputs.resourceId
                service: 'Dev'
                privateDnsZoneResourceIds: pepDnsZoneResourceId
            }
            {
                subnetResourceId: synapseSubnet.outputs.resourceId
                service: 'SqlOnDemand'
                privateDnsZoneResourceIds: pepDnsZoneResourceId
            }
        ]
    }
}
