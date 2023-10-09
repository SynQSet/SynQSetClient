#!/usr/bin/env pwsh
#region    Classes

class RkClient {
    # .SYNOPSIS
    #     SynQSet Client class
    # .DESCRIPTION
    #     A longer description of the Class, its purpose, common use cases, etc.
    RkClient() {}
    static Start ([string[]]$argList) {
        try {
            [System.Environment]::CurrentDirectory = $(Get-Variable ExecutionContext -ValueOnly).SessionState.Path.CurrentLocation.Path
            [string]$SynQSetExePath = [System.IO.Path]::Combine([System.Environment]::CurrentDirectory, 'SynQSet.exe');
            if ([IO.File]::Exists($SynQSetExePath)) {
                [string]$arguments = [string]::Join(" ", $argList)
                [string]$command = "$SynQSetExePath $arguments";
                [System.Diagnostics.Process]::Start('cmd.exe', $command)
            } else {
                [Console]::WriteLine("Error: 'SynQSet.exe' not found.")
            }
        } catch {
            [Console]::WriteLine("Error: $($_.Exception.Message)")
        }
    }
}
#endregion Classes
$Private = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Private')) -Filter "*.ps1" -ErrorAction SilentlyContinue
$Public = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Public')) -Filter "*.ps1" -ErrorAction SilentlyContinue
# Load dependencies
$PrivateModules = [string[]](Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Private')) -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty FullName)
if ($PrivateModules.Count -gt 0) {
    foreach ($Module in $PrivateModules) {
        Try {
            Import-Module $Module -ErrorAction Stop
        } Catch {
            Write-Error "Failed to import module $Module : $_"
        }
    }
}
# Dot source the files
foreach ($Import in ($Public, $Private)) {
    Try {
        . $Import.fullname
    } Catch {
        Write-Warning "Failed to import function $($Import.BaseName): $_"
        $host.UI.WriteErrorLine($_)
    }
}
# Export Public Functions
$Public | ForEach-Object { Export-ModuleMember -Function $_.BaseName }
#Export-ModuleMember -Alias @('<Aliases>')