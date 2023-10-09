function Get-GitHubReleaseLink {
    <#
    .SYNOPSIS
                Outputs latest GitHub Release.
            .DESCRIPTION
                Script to fetch the latest release from specified GitHub Repo if it is newer than the local copy
                and extract the content to local folder while stopping and starting a service.
            .PARAMETER name
                Name of the GitHub project (will be used to create directory in $RootPath)
            .PARAMETER repo
                Github Repository to target.
            .PARAMETER filenamePattern
                Filename pattern that will be looked for in the releases page, does except Powershell wildcards
            .PARAMETER RootPath
                The Root folder where the project need to be replicated to.
            .PARAMETER innerDirectory
                Needed it the project is zipped into a rootfolder.
            .PARAMETER preRelease
                Needed if pre releases are to be downloaded.
            .PARAMETER RestartService
                If specified will stop Service and dependents as specified before copy action, will start all services afterwards.
            .EXAMPLE
                Get-Latest-GitHub-Release.ps1 -repo 'filebrowser/filebrowser'
                Get-Latest-GitHub-Release.ps1 -repo 'Jackett/Jackett' -filenamePattern 'Jackett.Binaries.Windows.zip' -RootPath 'C:\Github' -innerDirectory -preRelease -RestartService 'Jackett'
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(mandatory = $true)]
        [string]$repo,
        [Parameter(mandatory = $false)]
        [string]$Name = $repo.Split('/')[1].Trim(),
        [Parameter(mandatory = $false)]
        [switch]$preRelease,
        [Parameter(mandatory = $false)]
        [string]$RestartService
    )

    begin {
        $script:StartService = [ScriptBlock]::Create({
                <#
                .SYNOPSIS
                    Start service and its dependencies.
                .DESCRIPTION
                    Will first start the dependencies and then the named service.
                .EXAMPLE
                    icm $StartService -ArgumentList 'netlogon'
                #>
                param (
                    # Name of service to start.
                    [Parameter(Mandatory = $true)]
                    [string]$Services
                )
                foreach ($sercice in $Services) {
                    Write-Message "Starting $sercice ..."
                    $Dependencies = Get-Service -Name $sercice -DependentServices
                    foreach ($depService in $Dependencies.name) {
                        Get-Service -Name $depService | Start-Service
                    }
                    Get-Service -Name $sercice | Start-Service
                }
            }
        )
        function InvokeRestMethod {
            # .DESCRIPTION
            #     Invoke-RestMethod but with error handling
            param (
                [Parameter(Mandatory = $true)]
                [ValidateNotNullOrEmpty()]
                [String]$Uri,
                [Parameter(Mandatory = $false, HelpMessage = "Method")]
                [ValidateSet("GET", "POST")]
                [String]$Method = "GET"
            )
            try {
                Invoke-RestMethod -Method $Method -Uri $Uri
            } catch {
                if ($_.ErrorDetails.Message) {
                    Write-Message 'Error' $_.ErrorDetails.Message
                } else {
                    Write-Message 'Error' $_.Exception.Message
                }
                Write-Message 'StatusCode:' $_.Exception.Response.StatusCode.value__
                Write-Message 'StatusDescription:' $_.Exception.Response.StatusDescription
            }
        }
        class ghrelease {
            static [PsObject] GetReleaseLinks([string]$gitHubreleasedlLink) {
                # Extract RepoOwner and RepoName from releasedlLink
                $gitH_rel_ = $gitHubreleasedlLink.Substring('https://github.com/'.Length).split('/')
                $RepoOwner = $gitH_rel_[0]
                $Repo_Name = $gitH_rel_[1]; $nsp = $gitH_rel_[-2].Split('-')[0..1] -join '-'
                $BinaryName = $gitH_rel_[-1].Substring($gitH_rel_[-1].IndexOf($nsp)).Replace("$nsp-", '')
                return [ghrelease]::GetReleaseLinks($RepoOwner, $Repo_Name, $BinaryName, 2, $false);
            }
            static [PsObject] GetReleaseLinks([string]$RepoOwner, [string]$Repo_Name, [string]$BinaryName) {
                return [ghrelease]::GetReleaseLinks($RepoOwner, $Repo_Name, $BinaryName, 2, $false);
            }
            static [PsObject] GetReleaseLinks([string]$RepoOwner, [string]$Repo_Name, [string]$BinaryName, [int]$SearchInCount, [bool]$Prerelease) {
                $Rest_reslt = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$Repo_Name/releases?per_page=$SearchInCount"
                $dl_version = ($Rest_reslt.Where{ $_.prerelease -eq $Prerelease }.tag_name | Select-String -Pattern "\d+.\d+.\d+").Matches.Value |
                    Sort-Object { [version]$_ } |
                    Select-Object -Last 1;
                $_x64_arch = $true
                $dl_Links = $($Rest_reslt.assets.browser_download_url -like "*$(if ($_x64_arch) {'-x86_64-'} else {'-i686-'})*$dl_version*$BinaryName*")
                $ReleaseLinks = [PSCustomObject]@{
                    dlUri     = [uri]::new($dl_Links[0])
                    sha256Uri = [uri]::new($dl_Links[1])
                    sha512Uri = [uri]::new($dl_Links[2])
                }
                return $ReleaseLinks
            }
        }
        # TODO: Add a regex scriptblock to check correct pattern git release download link
        # Disable progressbar on download to speed up the download
    }

    process {
        # It there is a service defined start it and it dependencies
        if (![string]::IsNullOrWhiteSpace($RestartService)) {
            Invoke-Command -ScriptBlock $StartService -ArgumentList $RestartService
        }
        # Install pre release or latest stable
        $BrowseResult = Invoke-Command -ScriptBlock {
            if ($preRelease) {
                $(InvokeRestMethod $("https://api.github.com/repos/$repo/releases"))[0]
            } elseif ($latest) {
                $(InvokeRestMethod $("https://api.github.com/repos/$repo/releases/latest"))[0]
            } else {
                $(InvokeRestMethod $("https://api.github.com/repos/$repo/releases"))[0]
            }
        }
        # try getting release data from $BrowseResult
        $dl = [System.Collections.ObjectModel.Collection[string]]::new()
        if (($BrowseResult -as 'array').count -ge 1) {
            $BrowseResult | ForEach-Object {
                if ($_.assets.count -gt 0) {
                    foreach ($asset in $_.assets) {
                        [void]$dl.add($asset.browser_download_url)
                    }
                }
            }
            if ($dl.Count -lt 0) {
                Write-Warning 'No download assets found!'
            }
        } else {
            throw 'No release URLs found'
        }
        $ReleaseLinks = @()
        for ($i = 0; $i -lt $dl.Count; $i += 3) {
            $ReleaseLinks += [PSCustomObject]@{
                dlUri     = [uri]::new($dl[$i])
                sha256Uri = [uri]::new($dl[$i + 1])
                sha512Uri = [uri]::new($dl[$i + 2])
            }
        }
        # Filter only those for this os arch
        $ReleaseLinks = $ReleaseLinks | Where-Object { $_.dlUri.OriginalString -like "*$(if ($_x64_arch) {'-x86_64-'} else {'-i686-'})*.zip" }
        # just select llvm version ([0])
        return $ReleaseLinks[0]
    }

    end {
        [System.GC]::Collect()
    }
}