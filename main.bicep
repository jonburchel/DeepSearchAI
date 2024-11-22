targetScope = 'subscription'

param environmentName string
param location string = 'eastus'
param tenantId string = tenant().tenantId
param bingSearchKey string

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'Basic'
      capacity: 1
    }
    kind: 'linux'
  }
}

var appEnvVariables = {
  AZURE_COSMOSDB_ACCOUNT: ''
  AZURE_COSMOSDB_CONVERSATIONS_CONTAINER:  ''
  AZURE_COSMOSDB_DATABASE: ''
  AZURE_COSMOSDB_ENABLE_FEEDBACK: ''
  AZURE_OPENAI_ENDPOINT: ''
  AZURE_OPENAI_MAX_TOKENS: 4096
  AZURE_OPENAI_MODEL: 'gpt-4o-mini'
  AZURE_OPENAI_MODEL_NAME: 'gpt-4o-mini'
  AZURE_OPENAI_RESOURCE: ''
  AZURE_OPENAI_STOP_SEQUENCE: ''
  AZURE_OPENAI_SYSTEM_MESSAGE: ''
  AZURE_OPENAI_TEMPERATURE: '0.7'
  BING_ENDPOINT: 'https://api.bing.microsoft.com'
  BING_SEARCH_KEY: bingSearchKey
  SCM_DO_BUILD_DURING_DEPLOYMENT: true
  UI_CHAT_DESCRIPTION: '<p style="margin-left: 8px;">UUFSolver helps you resolve your Unified User Feedback issues! Just paste details of your UUF issue into the chat and UUFSolver researches and suggests how to resolve it. You can ask follow up questions, too.<br/><br><center><table><tr><td><center><u><b>IMPORTANT:</b></u> When you use the tool, be sure to:</center><br/>• Validate the ground truth of any answer before using it in your work.<br/>• Add the <b>used-uuf-solver</b> tag to the UUF item in Azure DevOps.</br>• Add the <b>ai-usage: ai-assisted</b> tag to the article metadata.</td><tr></table></center></p>'
  UI_CHAT_LOGO: './ms-learn-guy.png'
  UI_CHAT_TITLE: 'UUFSolver'
  UI_FAVICON: './ms-learn-guy.png'
  UI_INFO_URL: 'https://dev.azure.com/UUFSolver/UUFSolver/_dashboards/dashboard/2a606a02-579c-43dc-9880-dcf52cb1e832'
  UI_LOGO: 'https://www.microsoft.com/favicon.ico?v2'
  UI_SEARCH_TEXT: 'Paste in the description field from a UUF item. Title and verbatim are mandatory, the rest of the fields are optional.'
  UI_SHOW_CHAT_HISTORY_BUTTON: true
  UI_SHOW_SHARE_BUTTON: true
  UI_TITLE: 'MSLearn UUFSolver'
  WEBSITE_AUTH_AAD_ALLOWED_TENANTS: '888d76fa-54b2-4ced-8ee5-aac1585adee7'
}


module backend 'core/host/appservice.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: '${abbrs.webSitesAppService}backend-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    // Need to check deploymentTarget again due to https://github.com/Azure/bicep/issues/3990
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.11'
    appCommandLine: 'python3 -m gunicorn main:app'
    scmDoBuildDuringDeployment: true
    managedIdentity: true
    enableUnauthenticatedAccess: true
    disableAppServicesAuthentication: false
    clientSecretSettingName: ''
    appSettings: appEnvVariables
  }
}
module openAi 'br/public:avm/res/cognitive-services/account:0.7.2' = if (isAzureOpenAiHost && deployAzureOpenAi) {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiResourceGroupLocation
    tags: tags
    kind: 'OpenAI'
    customSubDomainName: !empty(openAiServiceName)
      ? openAiServiceName
      : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      bypass: bypass
    }
    sku: openAiSkuName
    deployments: openAiDeployments
    disableLocalAuth: true
  }
}
/*
module openAiRoleUser 'core/security/role.bicep' = if (isAzureOpenAiHost && deployAzureOpenAi) {
  scope: openAiResourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: principalType
  }
}

module openAiRoleBackend 'core/security/role.bicep' = if (isAzureOpenAiHost && deployAzureOpenAi) {
  scope: openAiResourceGroup
  name: 'openai-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend.outputs.identityPrincipalId
      : acaBackend.outputs.identityPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}
*/
