# setup the machine how we want
Write-Host "Shutting down Blaise VM"

######################
# REMOVE AZURE AGENT
######################
$VSTS_AGENT_INPUT_TOKEN = Invoke-RestMethod http://metadata.google.internal/computeMetadata/v1/instance/attributes/BLAISE_AZURE_AGENT_INPUT_TOKEN -Headers @{"Metadata-Flavor"="Google"}
#$VSTS_AGENT_NAME = Invoke-RestMethod http://metadata.google.internal/computeMetadata/v1/instance/attributes/BLAISE_AZURE_AGENT_NAME -Headers @{"Metadata-Flavor"="Google"}

Write-Host "Removing VSTS Azure Agent..."
C:\dev\agent\config.cmd remove --unattended `
--auth PAT `
--token $VSTS_AGENT_INPUT_TOKEN

Write-Host "Completed removal of VSTS Azure Agent"
Get-Service | Where-Object {$_.Name -match "vstsagent"}
