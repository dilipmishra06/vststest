[CmdletBinding()]
param (
  [string]$connectedServiceName,
  [string]$keyVaultName,
  [string]$location,
  [string]$resourceGroupName
)


# Retrieve inputs
$connectedServiceName = Get-VstsInput -Name 'connectedServiceName'
$keyVaultName = Get-VstsInput -Name 'keyVaultName'
$location = Get-VstsInput -Name 'location'
$resourceGroupName = Get-VstsInput -Name 'resourceGroupName'

# Get the service connection details
$serviceConnection = Get-VstsEndpoint -Name $connectedServiceName -Require
$tenantId = $serviceConnection.Auth.Parameters.TenantId
$appId = $serviceConnection.Auth.Parameters.ServicePrincipalId
$appSecret = $serviceConnection.Auth.Parameters.ServicePrincipalKey


$secureClientSecret = ConvertTo-SecureString $appSecret -AsPlainText -Force
$credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $appId, $secureClientSecret

# Authenticate to Azure using the Az module
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential $credential


$parameters = @{
  name     = $keyVaultName
  location = $location
}

# Deploy the Bicep file with inline parameters
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "./bicep/createkeyvault.bicep" -TemplateParameterObject $parameters -DeploymentDebugLogLevel All