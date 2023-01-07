@description('The Azure region to install it')
param location string = 'germanywestcentral'

@description('Base name for all resources')
param baseName string

@description('The secret to access the /admin page of the Vaultwarden installation')
@secure()
param adminToken string

@description('If you are using sendgrid as a mail provider, set this to your API Key')
@secure()
param sendgridSmtpPassword string

resource logworkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law${baseName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'stgvaultwarden${baseName}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource fileservices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  name: 'default'
  parent: storage
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: 'vaultwarden'
  parent: fileservices
  properties: {
    enabledProtocols: 'SMB'
    shareQuota: 1024
  }
}

resource managedEnv 'Microsoft.App/managedEnvironments@2022-06-01-preview' = {
  name: 'managedEnv-${baseName}-vaultwarden'
  location: location
  sku: {
    name: 'Consumption'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logworkspace.properties.customerId
        sharedKey: logworkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource managedEnvStorage 'Microsoft.App/managedEnvironments/storages@2022-06-01-preview' = {
  name: fileshare.name
  parent: managedEnv
  properties: {
    azureFile: {
      accessMode: 'ReadWrite'
      shareName: fileshare.name
      accountName: storage.name
      accountKey: listKeys(storage.id, storage.apiVersion).keys[0].value
    }
  }
}

resource vaultwardenapp 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: 'vaultwarden${baseName}'
  location: location
  properties: {
    environmentId: managedEnv.id
    configuration: {
      secrets: [
        {
          name: 'fileshare-connectionstring'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
        }
        {
          name: 'admintoken'
          value: adminToken
        }
        {
          name: 'sendgridSmtpPassword'
          value: sendgridSmtpPassword
        }
      ]
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        allowInsecure: false
        targetPort: 80
        transport: 'auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }    
    template: {
      containers: [
        {          
          image: 'docker.io/vaultwarden/server:latest'
          name: 'vaultwarden'
          resources: {
            #disable-next-line BCP036
            cpu: '0.25'
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'AZURE_STORAGEFILE_CONNECTIONSTRING'
              secretRef: 'fileshare-connectionstring'
            }
            {
              name: 'SIGNUPS_ALLOWED'
              value: 'false'
            }                      
            {
              name: 'ADMIN_TOKEN'
              secretRef: 'admintoken'
            }            
            {
              name:'SMTP_HOST'
              value: 'smtp.sendgrid.net'
            }
            {
              name:'SMTP_PORT'
              value: '465'
            }
            {
              name:'SMTP_SECURITY'
              value: 'force_tls'
            }
            {
              name:'SMTP_USERNAME'
              value: 'apikey'
            }
            {
              name:'SMTP_PASSWORD'
              secretRef: 'sendgridSmtpPassword'
            }
            {
              name:'SMTP_AUTH_MECHANISM'
              value: 'Login'
            }
            {
              name: 'ENABLE_DB_WAL'
              value: 'true'
            }
            {
              name:'SHOW_PASSWORD_HINT'
              value: 'false'
            }
          ]
          volumeMounts: [
            {
              volumeName: fileshare.name
              mountPath: '/data'
            }
          ]
        }
      ]
      volumes: [
        {
          name: fileshare.name
          storageName: fileshare.name
          storageType: 'AzureFile'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}
