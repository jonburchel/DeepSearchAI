@description('Location for the resources')
param location string = resourceGroup().location

@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Managed Identity name')
param identityName string = 'UUF-Solver-my-identity'

@description('Azure OpenAI name')
param openAiResourceName string = 'DeepSearchTest'

@description('Resource token for naming consistency')
var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName, location))

var tags = {
  'azd-env-name': environmentName
}

#disable-next-line BCP081
resource bingSearch 'Microsoft.Bing/accounts@2020-06-10' = {
  name: 'UUFSolver-Web-Search-${resourceToken}'
  location: 'global'
  tags: tags
  kind: 'Bing.Search.v7'
  sku: {
    name: 'S1'
  }
}

// App Service Plan module
module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'appServicePlanDeploy'
  params: {
    name: 'asp-UUF-Solver-${resourceToken}'
    location: location
    skuName: 'P1V2'
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
    // appSettings: [
    //   { name: 'ENV_VAR'; value: 'SomeValue' }
    //   // Add more settings as needed
    // ]
  }
}


// Cosmos DB module
resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: 'kv-ref'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
  }
}

// Bing Resource module (use a custom or official module for Bing if available)
resource bingResource 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: 'BingSearch-${resourceToken}'
  location: location
  sku: {
    name: 'S1'
  }
  kind: 'Bing.Search'
  properties: {
    apiProperties: {}
  }
}

// Managed Identity resource
resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

// Azure OpenAI resource (assuming it’s supported in your region)
resource openAi 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: 'DeepSearchTest-${resourceToken}'
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: openAiResourceName
  }
}
