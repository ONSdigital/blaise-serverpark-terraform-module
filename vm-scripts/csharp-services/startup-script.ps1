#############
# functions
############
function GetMetadataVariables
{
  $variablesFromMetadata = Invoke-RestMethod http://metadata.google.internal/computeMetadata/v1/instance/attributes/?recursive=true -Headers @{ "Metadata-Flavor" = "Google" }
  return $variablesFromMetadata | Get-Member -MemberType NoteProperty
}

function CreateVariables($variableList)
{
  foreach ($variable in $variableList)
  {
    $varName = $variable.Name
    $varValue = $variable.Definition

    # The variable value (varValue) above is in the format NAME = VALUE.
    # We only want the variables that include 'BLAISE' or 'SCRIPT' in the name
    # This pattern will help extract the VALUE by removing the 'NAME =' part.
    $pattern = "^(.*?)$([regex]::Escape($varName) )(.?=)(.*)"

    if ($varName -Like "BLAISE_*" -or $varName -Like "SCRIPT_*")
    {
      New-Variable -Scope script -Name ($varName -replace "BLAISE_", "") -Value ($varValue -replace $pattern, '$3')
      Write-Host "Script Var: $varName = $( $varValue -replace $pattern, '$3' )"
    }
    if ($varName -Like "ENV_*")
    {
      [System.Environment]::SetEnvironmentVariable($varName, ($varValue -replace $pattern, '$3'), [System.EnvironmentVariableTarget]::Machine)
      Write-Host "Env Var   : $varName = $( $varValue -replace $pattern, '$3' )"
    }
  }
}

function WaitForServiceToRun($serviceName)
{
  $GrabService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

  while (!$GrabService -or $GrabService.Status -ne 'Running')
  {
    Write-Host 'Waiting for' $ServiceName 'to start'
    Start-Sleep -seconds 30
    $GrabService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    $GrabService.Refresh()
  }

  Get-Service -Name $serviceName
}

function CreateLoggingConfigurationFile($services, $configTemplate)
{
  $logAgentConfig =  'C:\dev\stackdriver\loggingAgent\config.d\logging.conf'

  # Create a log file for each service
  $services.GetEnumerator() `
  | Select-Object Name,Value `
  | ForEach-Object{
    ($configTemplate) `
    -replace "{{SERVICE_NAME}}", $_.Name  `
    -replace "{{LOG_FILE_NAME}}", $_.Value
  } `
  | Set-Content $logAgentConfig -Force
}

function SetupAzure
{
  ######################
  # INSTALL AZURE AGENT
  ######################

  $VSTS_AGENT_ARCHIVE_FILENAME = "vsts-agent-win-x64-2.179.0.zip"
  gsutil cp gs://$GCP_BUCKET/$VSTS_AGENT_ARCHIVE_FILENAME "C:\dev\data"
  Expand-Archive -Force C:\dev\data\$VSTS_AGENT_ARCHIVE_FILENAME C:\dev\agent\


  # we must use 'replace' on this option because if the user exists and we do not put replace
  # the process will not create local data in the .agent subdir, and the remove script on
  # shutdown will not work; so we will never remove a user if the shutdown script ever fails.
  Write-Host "Configuring Azure Agent Service..."
  C:\dev\agent\config.cmd --unattended `
  --environment `
  --environmentname $AZURE_AGENT_ENV_NAME `
  --agent $(Hostname) `
  --runasservice --work '_work' `
  --url $AZURE_PROJECT_URL `
  --projectname 'csharp' `
  --auth PAT `
  --token $AZURE_AGENT_INPUT_TOKEN `
  --replace TRUE
}

If (Test-Path D:) {
  Write-Host "Restarting Blaise VM"
  Write-Host "Setting up variables..."
  $metadataVariables = GetMetadataVariables
  CreateVariables($metadataVariables)
  SetupAzure
  exit
}

# setup the machine how we want
Write-Host "Initialising Blaise VM"

################
# SetupFirewall
################
Write-Host "Configuring firewall for Blaise client access"
New-NetFirewallRule -DisplayName "Blaise" -Direction Outbound -RemotePort 80, 443, 8031, 8033 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Blaise" -Direction Inbound -LocalPort 80, 443, 8031, 8033 -Protocol TCP -Action Allow

########################
# DisableWindowsUpdates
########################
Write-Host "Disabling windows update"
Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AUOptions -Value 1

###############################
# Set GMT with DaylightSavings
###############################

Set-TimeZone -Name "GMT Daylight Time"

#
# make dirs for storing Blaise and VSTS redistributables
#
Write-Host "Creating 'C:\dev' for Blaise and VSTS redistributables"
New-Item -Path "C:\" -Name "dev" -ItemType "directory"
New-Item -Path "C:\dev\" -Name "data" -ItemType "directory"
New-Item -Path "C:\dev\" -Name "agent" -ItemType "directory"
New-Item -Path "C:\dev\" -Name "stackdriver" -ItemType "directory"

$pathToServiceList = "C:\dev\stackdriver\serviceList.txt"
$pathToLog = "C:\BlaiseServices\BlaiseServiceStatus\logs\blaise-service-status.log"
New-Item -Path "C:\BlaiseServices\BlaiseServiceStatus\logs\" -Force -ItemType "directory"
New-Item -Path $pathToLog -ItemType File
###############
# RUNTIME ARGS
###############

Write-Host "Setting up script and system variables..."
$metadataVariables = GetMetadataVariables
CreateVariables($metadataVariables)

########################################
# INSTALL LOGGING AND MONITORING AGENTS
########################################
Write-Host "Installing Stackdriver agents..."
$stackdriverArchiveFilename = "stackdriver.zip"

Write-Host "Download Stackdriver logging and monitoring agent installer from '$GCP_BUCKET'..."
gsutil cp gs://$GCP_BUCKET/$stackdriverArchiveFilename "C:\dev\data"

Write-Host "Expanding archive to stackdriver directory..."
Expand-Archive C:\dev\data\stackdriver.zip C:\dev\stackdriver

Write-Host "Starting logging and monitoring agents (on the background)..."
C:\dev\stackdriver\StackdriverMonitoring-GCM-46.exe /S /D="C:\dev\stackdriver\monitoringAgent"
C:\dev\stackdriver\StackdriverLogging-v1-11.exe /S /D="C:\dev\stackdriver\loggingAgent"

######################
# CREATE WINDOWS USER
######################
$SECURE_PASSWORD = ConvertTo-SecureString $WINDOWS_PASSWORD -AsPlainText -Force

Write-Host "Creating Windows Username and Password"
New-LocalUser -Name $WINDOWS_USERNAME -Password $SECURE_PASSWORD -PasswordNeverExpires -UserMayNotChangePassword -AccountNeverExpires
Add-LocalGroupMember -Group "Administrators" -Member "$WINDOWS_USERNAME"

######################
# INSTALL AZURE AGENT
######################

SetupAzure

############################
# CONFIGURING LOGGING AGENT
############################
# Get list of Blaise Services
$stackdriverService = 'StackdriverLogging'
$servicesHashTable = ConvertFrom-StringData -StringData $SERVICES_LIST

WaitForServiceToRun($stackdriverService)

Write-Host "Setting up service status scripts..."
Set-Content -Path 'C:\dev\stackdriver\logsServiceFailure.ps1' -Value $SCRIPT_LOGS_SERVICE_FAILURE
Set-Content -Path 'C:\dev\stackdriver\logsServiceStatus.ps1' -Value $SCRIPT_LOGS_SERVICE_STATUS

Write-Host "Write list of services to a file"
$servicesHashTable.Keys | Out-String | Set-Content -Path $pathToServiceList

# Configure logging agent based on template passed as variable
Write-Host "Creating configuration file for logging agent..."
CreateLoggingConfigurationFile $servicesHashTable $SCRIPT_LOGS_CONFIG_TEMPLATE

Write-Host "Restarting logging agent..."
Restart-Service -Name $stackdriverService -Force

Write-Host "Creating scheduled task to log service status"
$action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "C:\dev\stackdriver\logsServiceStatus.ps1 -pathToServiceList $pathToServiceList -pathToLog $pathToLog"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
-RepetitionInterval (New-TimeSpan -Minutes 2) `
-RepetitionDuration (New-TimeSpan -Hours 24) `
-RandomDelay (New-TimeSpan -Seconds 10)

Register-ScheduledTask -user $WINDOWS_USERNAME -password $WINDOWS_PASSWORD -Action $action -Trigger $trigger -TaskName 'ServiceStatus' -Description 'Report service status for our Blaise Services'

#################
# SERVICE STATUS
#################

Write-Host "Service Status"
Get-Service "BlaiseServices5"
Get-Service | Where-Object {$_.Name -match "vstsagent"}
Get-Service -Name StackdriverLogging
Get-Service -Name StackdriverMonitoring
