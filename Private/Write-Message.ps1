function Write-Message {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Type,
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 1)]
        [string]$Message
    )
    process {
        if ($null -eq $Type -or $Type -eq "") {
            $Type = "$([char]91)Info$([char]93)"
        } else {
            $Type = "$([char]91)$Type$([char]93)"
        }
        $MyDate = "$([char]91){0:MM/dd/yy} {0:HH:mm:ss}$([char]93)" -f (Get-Date)
        [System.Console]::WriteLine("$MyDate - $Type : $Message" )
    }
}