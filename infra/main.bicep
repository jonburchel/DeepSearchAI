targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

var abbreviations = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

@minLength(1)
@allowed([
  'eastus2'
  'eastus'
  'japaneast'
  'uksouth'
  'northeurope'
  'swedencentral'
  'westus3'
])
@description('Primary location for all resources.')
param location string

@description('Id of the principal to assign database and application roles.')
param principalId string = ''

// Optional parameters
var resourceGroupName = 'uuf-solver-${resourceToken}'
var openAiAccountName = 'ai-${resourceToken}'
var cosmosDbAccountName = 'db-${resourceToken}'
var userAssignedIdentityName = 'mi-${resourceToken}'
var appServicePlanName = 'plan-${resourceToken}'
var appServiceWebAppName = 'web-app-${resourceToken}'

// serviceName is used as value for the tag (azd-service-name) azd uses to identify deployment host
var serviceName = 'web-${resourceToken}'


var tags = {
  'azd-env-name': environmentName
  'app-name': resourceGroupName
  'resource-token': resourceToken
}

var chatSettings = {
  maxConversationTokens: '100'
  cacheSimilarityScore: '0.99'
  productMaxResults: '10'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module identity 'app/identity.bicep' = {
  name: 'identity-${resourceToken}'
  scope: resourceGroup
  params: {
    identityName: !empty(userAssignedIdentityName) ? userAssignedIdentityName : '${abbreviations.userAssignedIdentity}-${resourceToken}'
    location: location
    tags: tags
  }
}

module ai 'app/ai.bicep' = {
  name: 'ai-${resourceToken}'
  scope: resourceGroup
  params: {
    accountName: !empty(openAiAccountName) ? openAiAccountName : '${abbreviations.openAiAccount}-${resourceToken}'
    location: location
    tags: tags
  }
}

module web 'app/web.bicep' = {
  name: 'webapp-${resourceToken}'
  scope: resourceGroup
  params: {
    appName: !empty(appServiceWebAppName) ? appServiceWebAppName : '${abbreviations.appServiceWebApp}-${resourceToken}'
    planName: !empty(appServicePlanName) ? appServicePlanName : '${abbreviations.appServicePlan}-${resourceToken}'
    databaseAccountEndpoint: database.outputs.endpoint
    openAiAccountEndpoint: ai.outputs.endpoint
    openAiResourceName: ai.outputs.name
    cosmosDbSettings: {
      account: database.outputs.accountName
      database: database.outputs.database.name
      conversationsContainer: database.outputs.containers[0].name
      
    }
   
    openAiSettings: {
      completionDeploymentName: ai.outputs.deployments[0].name
      embeddingDeploymentName: ''
    }
    chatSettings: {
      maxConversationTokens: chatSettings.maxConversationTokens
      cacheSimilarityScore: chatSettings.cacheSimilarityScore
      productMaxResults: chatSettings.productMaxResults
    }
    // userAssignedManagedIdentity: {
    //   resourceId: identity.outputs.resourceId
    //   clientId: identity.outputs.clientId
    // }
    location: location
    tags: tags
    serviceTag: serviceName

    openAiDeployments: ai.outputs.deployments
 }
}

module database 'app/database.bicep' = {
  name: 'db-${resourceToken}'
  scope: resourceGroup
  params: {
    accountName: !empty(cosmosDbAccountName) ? cosmosDbAccountName : '${abbreviations.cosmosDbAccount}-${resourceToken}'
    location: location
    tags: tags
  }
}

module security 'app/security.bicep' = {
  name: 'security'
  scope: resourceGroup
  params: {
    databaseAccountName: database.outputs.accountName
    appPrincipalId: web.outputs.webappManagedIdentity //identity.outputs.principalId
    userPrincipalId: !empty(principalId) ? principalId : null
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.10.2' = {
  name: 'key-vault'
  scope: resourceGroup
  params: {
    name: 'key-vault-${resourceToken}'
    location: location
    sku: 'standard'
    enablePurgeProtection: false
    enableSoftDelete: false
    publicNetworkAccess: 'Enabled'
    enableRbacAuthorization: true
    secrets: [
      {
        name: 'bing-search-key'
        value: ''
      }
    ]
  }
}
var keyVaultRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
) // Key Vault Secrets User built-in role

module keyVaultAppAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  name: 'key-vault-role-assignment-secrets-user'
  params: {
    principalId: principalId
    resourceId: keyVault.outputs.resourceId
    roleDefinitionId: keyVaultRole
  }
}

// Database outputs
output AZURE_COSMOS_DB_ENDPOINT string = database.outputs.endpoint
output AZURE_COSMOS_DB_DATABASE_NAME string = database.outputs.database.name
output AZURE_COSMOS_DB_CHAT_CONTAINER_NAME string = database.outputs.containers[0].name
output AZURE_COSMOS_DB_PRODUCT_DATA_SOURCE string = ''

// AI outputs
output AZURE_OPENAI_ACCOUNT_ENDPOINT string = ai.outputs.endpoint
output AZURE_OPENAI_COMPLETION_DEPLOYMENT_NAME string = ai.outputs.deployments[0].name

// web outputs
output AZURE_UUF_WEB string = web.outputs.endpoint
