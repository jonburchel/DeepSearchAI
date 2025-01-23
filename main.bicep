@description('Location for the resources')
param location string = resourceGroup().location

@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Managed Identity name')
param identityName string = 'UUF-Solver-my-identity'

@description('Resource token for naming consistency')
var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName, location))


// Microsoft has disabled new Bing Search resources
// needs eastus2 region
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
    // appSettings: [
    //   { name: 'ENV_VAR'; value: 'SomeValue' }
    //   // Add more settings as needed
    // ]
  }
}

// Managed Identity resource
resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

// Azure OpenAI resource (assuming it’s supported in your region)
resource openAi 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: 'DeepSearchUUF-${resourceToken}'
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: 'openAiResource-${resourceToken}'
  }
}
