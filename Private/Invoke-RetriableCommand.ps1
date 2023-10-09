function Invoke-RetriableCommand {
    <#
            .SYNOPSIS
                Runs Retriable Commands
            .DESCRIPTION
                Retries a script process for a number of times or until it completes without terminating errors.
                All Unnamed arguments will be passed as arguments to the script
            .NOTES
                Information or caveats about the function e.g. 'This function is not supported in Linux'
            .LINK
                https://github.com/alainQtec/.files/blob/main/src/scripts/ProcessMan/Invoke-RetriableCommand.ps1
            .EXAMPLE
                Invoke-RetriableCommand -ScriptBlock $downloadScript -CancellationToken $cts.Token -Verbose
                Retries the download script 3 times (default)
            #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ScriptBlock')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ScriptBlock')]
        [Alias('Script')]
        [ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Command')]
        [Alias('Command', 'CommandPath')]
        [System.string]$FilePath,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__AllParameterSets')]
        [System.Object[]]$ArgumentList,

        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = '__AllParameterSets')]
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None,

        [Parameter(Mandatory = $false, Position = 3, ParameterSetName = '__AllParameterSets')]
        [Alias('Retries', 'MaxRetries')]
        [int]$MaxAttempts = 3,

        [Parameter(Mandatory = $false, Position = 4, ParameterSetName = '__AllParameterSets')]
        [int]$SecondsBetweenAttempts = 1,

        [Parameter(Mandatory = $false, Position = 5, ParameterSetName = '__AllParameterSets')]
        [string]$Message = "Running $('[' + $MyInvocation.MyCommand.Name + ']')"
    )
    DynamicParam {
        $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
        $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
            Position                        = 6
            ParameterSetName                = '__AllParameterSets'
            Mandatory                       = $False
            ValueFromPipeline               = $true
            ValueFromPipelineByPropertyName = $true
            ValueFromRemainingArguments     = $true
            HelpMessage                     = 'Allows splatting with arguments that do not apply. Do not use directly.'
            DontShow                        = $False
        }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
        $attributeCollection.Add($attributes)
        $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
        $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
        return $DynamicParams
    }

    begin {
        [System.Management.Automation.ActionPreference]$eap = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
        $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
        $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
        $Output = [string]::Empty
        $Result = [PSCustomObject]@{
            Output      = $Output
            IsSuccess   = [bool]$IsSuccess # $false in this case
            ErrorRecord = $null
        }
    }

    process {
        Write-Invocation $MyInvocation
        $Attempts = 1
        $CommandStartTime = Get-Date
        while (($Attempts -le $MaxAttempts) -and !$Result.IsSuccess) {
            $Retries = $MaxAttempts - $Attempts
            if ($cancellationToken.IsCancellationRequested) {
                Out-Verbose $fxn "CancellationRequested when $Retries retries were left."
                throw
            }
            try {
                Out-Verbose $fxn "$Message Retry Attempt # $Attempts/$MaxAttempts ..."
                $downloadAttemptStartTime = Get-Date
                if ($PSCmdlet.ShouldProcess("$fxn Retrying <Command>. Attempt # $Attempts/$MaxAttempts", '<Command>', "Retrying")) {
                    if ($PSCmdlet.ParameterSetName -eq 'Command') {
                        try {
                            $Output = & $FilePath $ArgumentList
                            $IsSuccess = [bool]$?
                        } catch {
                            $IsSuccess = $false
                            $ErrorRecord = $_.Exception.ErrorRecord
                            # Write-Log $_.Exception.ErrorRecord
                            Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
                        }
                    } else {
                        $Output = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
                        $IsSuccess = [bool]$?
                    }
                }
            } catch {
                $IsSuccess = $false
                $ErrorRecord = [System.Management.Automation.ErrorRecord]$_
                # Write-Log $_.Exception.ErrorRecord
                Out-Verbose $fxn "Error encountered after $([math]::Round(($(Get-Date) - $downloadAttemptStartTime).TotalSeconds, 2)) seconds"
            } finally {
                $Result = [PSCustomObject]@{
                    Output      = $Output
                    IsSuccess   = $IsSuccess
                    ErrorRecord = $ErrorRecord
                }
                if ($Retries -eq 0 -or $Result.IsSuccess) {
                    $ElapsedTime = [math]::Round(($(Get-Date) - $CommandStartTime).TotalSeconds, 2)
                    $EndMsg = $(if ($Result.IsSuccess) { "Completed Successfully. Total time elapsed $ElapsedTime" } else { "Completed With Errors. Total time elapsed $ElapsedTime. Check the log file $LogPath" })
                    Out-Verbose $fxn "Returning Objects"
                } elseif (!$cancellationToken.IsCancellationRequested -and $Retries -ne 0) {
                    Out-Verbose $fxn "Waiting $SecondsBetweenAttempts seconds before retrying. Retries left: $Retries"
                    Start-Sleep $SecondsBetweenAttempts
                }
                $Attempts++
            }
        }
    }

    end {
        Out-Verbose $fxn "$EndMsg"
        $ErrorActionPreference = $eap;
        return $Result
    }
}