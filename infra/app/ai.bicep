metadata description = 'Create AI accounts.'

param accountName string
param location string = resourceGroup().location
param tags object = {}

var deployments = [
  {
    name: 'gpt-4o-mini'
    skuCapacity: 1
    modelName: 'gpt-4o-mini'
    modelVersion: '2024-07-18'
  }
]

module openAiAccount '../core/ai/cognitive-services/account.bicep' = {
  name: 'DeepSearchAI'
  params: {
    name: accountName
    location: location
    tags: tags
    kind: 'OpenAI'
    sku: 'S0'
    enablePublicNetworkAccess: true
  }
}

@batchSize(1)
module openAiModelDeployments '../core/ai/cognitive-services/deployment.bicep' = [
  for (deployment, _) in deployments: {
    name: 'openai-model-deployment-${deployment.name}'
    params: {
      name: deployment.name
      parentAccountName: openAiAccount.outputs.name
      skuName: 'GlobalStandard'
      skuCapacity: deployment.skuCapacity
      modelName: deployment.modelName
      modelVersion: deployment.modelVersion
      modelFormat: 'OpenAI'
    }
  }
]

output name string = openAiAccount.outputs.name
output endpoint string = openAiAccount.outputs.endpoint
output deployments array = deployments

