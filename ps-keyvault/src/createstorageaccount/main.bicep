// @description('Deployment Location')
// param location string

// param name string

// resource st 'Microsoft.Storage/storageAccounts@2022-09-01' = {
//   name: name
//   location: location
//   sku: {
//     name: 'Standard_LRS'
//   }
//   kind: 'StorageV2'
//   properties: {
//     accessTier: 'Hot'
//   }
//   tags: {}
// }

// output storageAccountId string = st.id
// output storageAccountName string = st.name

param name string
param location string

module storageaccount 'storageaccountbicep/storage.bicep' = {
  name: 'storageaccount-deployment'
  params: {
    name: name
    location: location
  }
}
