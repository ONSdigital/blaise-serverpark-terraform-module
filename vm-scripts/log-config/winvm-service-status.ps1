
param(
  [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
  [System.String]
  $pathToServiceList,

  [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
  [ValidateScript({ Test-Path -Path "$_" })]
  [System.String]
  $pathToLog)

function LogServiceStatus($serviceName, $logPath)
{
  If (Get-Service $serviceName -ErrorAction SilentlyContinue)
  {
    If ((Get-Service $serviceName).Status -eq 'Running')
    {
      $outputMessage = $serviceName + " is running"
      $level = "info"
      [string]$status = "2"
    }
    Else
    {
      $outputMessage = $serviceName + " found, but it is not running."
      $level = "Warning"
      [string]$status = "1"
    }
  }
  Else
  {
   $outputMessage = "$serviceName not found"
   $level = "Warning"
   [string]$status = "0"
  }
  $logOutput = @{log=@{time="$((Get-Date).ToString())";service="$serviceName";status="$status";level="$level";message="$outputMessage"}}
  $logOutput | ConvertTo-Json -Compress | Out-File $logPath -Encoding utf8 -Append
}


$serviceList = Get-Content -Path $pathToServiceList

$serviceList.GetEnumerator() | ForEach-Object { LogServiceStatus $_ $pathToLog }
