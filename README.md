# Vaultwarden on Azure Container Apps

This repo contains the bicep files to deploy [Vaultwarden](https://github.com/dani-garcia/vaultwarden) on an Azure Container App. It also contains an empty SQLite database required to setup Vaultwarden using an Azure file share.

For more details visit my blog post: [https://blog.mwiedemeyer.de/post/2023/Vaultwarden-Bitwarden-on-Azure-Container-Apps/](https://blog.mwiedemeyer.de/post/2023/Vaultwarden-Bitwarden-on-Azure-Container-Apps/)

To run this template you can execute:

`az deployment group create --resource-group YOU_RESOURCE_GROUP_NAME --template-file main.bicep`

or click this button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmwiedemeyer%2Fvaultwarden-on-azure-container-apps%2Fmain%2Fmain.json)
