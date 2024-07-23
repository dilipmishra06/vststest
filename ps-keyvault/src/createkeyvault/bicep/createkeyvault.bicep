param name string
param location string

module keyvault '../keyvaultbicep/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    name: name
    location: location
  }
}
