param([Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $false)]
    [System.String]
    $ServiceName
)

function logServiceFailure($ServiceName)
{

	[string]$msg = "$((Get-Date).ToString() ) -- Service: " + $ServiceName + " has an unexpected failure"
	Add-Content C:\BlaiseServices\BlaiseServiceFailure\logs\blaise-service-failure.tmp $msg

	Copy-Item C:\BlaiseServices\BlaiseServiceFailure\logs\blaise-service-failure.tmp C:\BlaiseServices\BlaiseServiceFailure\logs\blaise-service-failure.log
}

logServiceFailure($ServiceName)
