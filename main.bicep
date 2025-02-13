// filepath: /Code/DeepSearchAI/main.bicep

@description('Location for the resources')
param location string = resourceGroup().location

@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Managed Identity name')
param identityName string = 'UUF-Solver-my-identity'

// Contributor role definition ID
var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var searchDataReaderId = '7d2a6a18-3955-47a6-bbf0-81279f583a02'

@description('Resource token for naming consistency')
var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName, location))

// Azure Cognitive Search
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: 'mysearch-${resourceToken}'
  location: location
  sku: {
    name: 'basic'
  }
  properties: {
    hostingMode: 'default'
  }
}

// App Service Plan module
module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'appServicePlanDeploy'
  scope: resourceGroup()
  params: {
    name: 'asp-UUF-Solver-${resourceToken}'
    location: location
    skuName: 'B2'
    skuCapacity: 1
  }
}

// Web App module
module appServiceWebApp 'br/public:avm/res/web/site:0.13.0' = {
  name: 'UUF-Solver'
  scope: resourceGroup()
  params: {
    name: 'UUF-Solver-${resourceToken}'
    location: location
    serverFarmResourceId: appServicePlan.outputs.resourceId
    kind: 'app'
    managedIdentities: {
      userAssignedResourceIds: [
        userManagedIdentity.id
      ]
    }
  }
}

// Managed Identity resource
resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

// Assign Search Data Reader role to the identity, scoped to the Cognitive Search resource
resource searchDataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, userManagedIdentity.name, searchDataReaderId)
  scope: searchService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', searchDataReaderId)
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Azure OpenAI resource
resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'DeepSearchUUF-${resourceToken}'
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    // ...any required properties for your OpenAI resource
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
}

// // Model Deployment Resource
// resource openAiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2022-12-01' = {
//   parent: openAi
//   name: 'gpt-4o-mini-deployment'
//   properties: {
//     model: {
//       name: 'gpt-4o-mini' // Ensure this is a valid model name in your Azure OpenAI service
//       format: 'OpenAI'
//     }
//     scaleSettings: {
//       scaleType: 'Manual' // Adjust as needed; 'Manual' may not be supported for some models
//       capacity: 3
//     }
//   }
// }

// Role Assignment for Contributor on the App Service
resource contributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appServiceWebApp.name, userManagedIdentity.name, contributorRoleDefinitionId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
