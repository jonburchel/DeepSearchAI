metadata description = 'Create web apps.'

param planName string
param appName string
param serviceTag string
param location string = resourceGroup().location
param tags object = {}

@description('SKU of the App Service Plan.')
param sku string = 'B1'

@description('Endpoint for Azure Cosmos DB for NoSQL account.')
param databaseAccountEndpoint string

@description('Endpoint for Azure OpenAI account.')
param openAiAccountEndpoint string

@description('Name of the parent Azure OpenAI account.')
param openAiResourceName string

param openAiDeployments array = []

type openAiOptions = {
  completionDeploymentName: string
  embeddingDeploymentName: string
}

@description('Application configuration settings for OpenAI.')
param openAiSettings openAiOptions

type cosmosDbOptions = {
  account: string
  database: string
  conversationsContainer: string
}
@description('Application configuration settings for Azure Cosmos DB.')
param cosmosDbSettings cosmosDbOptions

type chatOptions = {
  maxConversationTokens: string
  cacheSimilarityScore: string
  productMaxResults: string
}

@description('Application configuration settings for Chat Service.')
param chatSettings chatOptions

type managedIdentity = {
  resourceId: string
  clientId: string
}

@description('Unique identifier for user-assigned managed identity.')
param userAssignedManagedIdentity managedIdentity

module appServicePlan '../core/host/app-service/plan.bicep' = {
  name: 'app-service-plan'
  params: {
    name: planName
    location: location
    tags: tags
    sku: sku
    kind: 'linux'
  }
}

module appServiceWebApp '../core/host/app-service/site.bicep' = {
  name: 'app-service-web-app'
  params: {
    name: appName
    location: location
    tags: union(tags, {
      'azd-service-name': serviceTag
    })
    parentPlanName: appServicePlan.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    kind: 'app,linux'
    enableSystemAssignedManagedIdentity: false
    userAssignedManagedIdentityIds: [
      userAssignedManagedIdentity.resourceId
    ]
  }
}

param uiChatDescription string = '<br><br><div style="text-align: center;">UUFSolver helps you resolve your Unified User Feedback issues! Just paste the details of your UUF issue into the chat, and UUFSolver researches and suggests how to resolve it. You can ask follow up questions, too! </div><br><br><div id="tips" style="margin: 0 auto; width: 70%; text-align: left; display: flex; justify-content: center;"><div style="text-align: left;"><p><ul>When using the tool, be sure to:<li><div>Validate the ground truth of any answer before using it in your work</div></li><li><div>Add this tag to the UUF item in Azure DevOps: <div style="color: rgb(60, 60, 5); font-weight: bold;">used-uuf-solver</div></div></li><li><div>Add this to the article metadata: <div style="color: rgb(60, 60, 5); font-weight: bold;">ai-usage:ai-assisted</div></li></ul></p></div></div></div>'
param systemMessage string = 'You assist content developers/writers in implementing improvements to their articles on https://learn.microsoft.com based on customer feedback on the articles. You will be prompted with an Article, which is the URL of the article in question, and Feedback, which is the customer feedback. Propose updates to the article to address the feedback. Include detailed reference links with footnotes for all your statements so the content developers can validate ground truth before making any changes to their articles. Answer their follow up questions to help them understand better as necessary, searching when necessary to always document your technical suggestions with external references that you confirm in searches you can perform. In your initial response, remind them to validate ground truth as a central duty of their role. Entitle the chat with the title of the article in question. When the user provides you the required details, format your output like this markdown template, use active voice and replace `this` with the correct noun:\n\n\n "## IMPORTANT \n\nWhen using the tool, be sure to:\n\n* Validate the ground truth of the response before using it in your work as per [guidance in the Docs Contributors Guide](https://review.learn.microsoft.com/en-us/help/contribute/guidance-for-ai-generated-content?branch=main#how-to-add-ai-usage-metadata-to-ai-generated-content)\n\n* Add the following tag to your UUF item in Azure DevOps: **used-uuf-solver**\n\n* Add the following attribute to your article metadata: **ai-usage:ai-assisted**\n\n## Article\n<Title of the article, formatted as a link to it>\n## Feedback\n<The user feedback>\n### Proposed updates\n<Here include full proposal with examples and references and quotes from reference material (being sure to use at least 3-6 references from your previously gathered backtground information). Use subsections with H3s (###) and H4s (####), and any other formatting necessary to clearly present the proposed changes and your reasoning for proposing them.>\n## Additional considerations/Examples/etc. (optional)\nYou can call this section whatever is appropriate for it if you need another section for any reason at the end.)\n## References\n<include links for all the references made in the sections above, each assigned to the relevant footnote number(s) where it was referenced in the answer. This should be a bibliography of links to sources referenced in the proposed changes."\n\nIf the user asks a question about a different item of feedback after you already discussed on with them, ask them to open a new chat so each feedback issue will stay addressed in a single chat. But if they need to discuss further to understand fully the answer and impact, then go as deep as they need to go, in normal conversation, helping them research with the search feature available to you when you before you answer these queries. You do not have to use the template except when making proposals to address feedback - not when answering follow up questions. But even for follow up questions consider searches to find references to document your answers as much as necessary.'

module appServiceWebAppConfig '../core/host/app-service/config.bicep' = {
  name: 'app-service-config'
  params: {
    parentSiteName: appServiceWebApp.outputs.name
    appSettings: {

      AZURE_OPENAI_MODEL: openAiDeployments[0].name
      AZURE_OPENAI_MODEL_NAME: openAiDeployments[0].name
      AZURE_OPENAI_RESOURCE: openAiResourceName
      AZURE_OPENAI_STREAM:true
      AZURE_OPENAI_ENDPOINT:openAiAccountEndpoint
      AZURE_OPENAI_TEMPERATURE: '0.7'
      AZURE_OPENAI_TOP_P: '0.95'
      AZURE_OPENAI_MAX_TOKENS: '4096'
      AZURE_OPENAI_STOP_SEQUENCE: ''
      AZURE_OPENAI_SEED:''
      AZURE_OPENAI_CHOICES_COUNT: '1'
      AZURE_OPENAI_PRESENCE_PENALTY: '0.0'
      AZURE_OPENAI_FREQUENCY_PENALTY: '0.0'
      AZURE_OPENAI_LOGIT_BIAS: ''
      AZURE_OPENAI_USER: ''
      AZURE_OPENAI_TOOLS: ''
      AZURE_OPENAI_TOOL_CHOICE: ''
      AZURE_OPENAI_SYSTEM_MESSAGE: systemMessage
      AZURE_OPENAI_KEY: 'fc065c5d3e644e7e811933062772ac6f'
      BING_SEARCH_KEY: 'bab3bad7dc564cbeb39c5d4843c5a280'
      BING_ENDPOINT: 'https://api.bing.microsoft.com'
      AZURE_COSMOSDB_ACCOUNT: cosmosDbSettings.account
      AZURE_COSMOSDB_ENDPOINT: databaseAccountEndpoint
      AZURE_COSMOSDB_DATABASE: cosmosDbSettings.database
      AZURE_COSMOSDB_CONVERSATIONS_CONTAINER: cosmosDbSettings.conversationsContainer
      AZURE_COSMOSDB_ENABLE_FEEDBACK: 'true'
      UI_TITLE: 'MSLearn UUFSolver'
      UI_LOGO: 'https://www.microsoft.com/favicon.ico?v2'
      UI_CHAT_LOGO: '/ms-learn-guy.png'
      UI_CHAT_TITLE: 'UUFSolver'
      UI_CHAT_DESCRIPTION: uiChatDescription
      UI_FAVICON: 'https://www.microsoft.com/favicon.ico?v2'
      UI_SHOW_SHARE_BUTTON: 'true'
      UI_INFO_URL: 'https://dev.azure.com/UUFSolver/UUFSolver/_dashboards/dashboard/2a606a02-579c-43dc-9880-dcf52cb1e832'
    }
  }
}

output name string = appServiceWebApp.outputs.name
output endpoint string = appServiceWebApp.outputs.endpoint
