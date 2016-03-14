Function Get-DotFiles {
    <#
        .SYNOPSIS
        Enumerates the available dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of enumerated components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is True.
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    Get-DotFilesSettings @PSBoundParameters
    $script:InstalledPrograms = Get-InstalledPrograms

    $Components = Get-ChildItem -Path $script:DotFilesPath -Directory
    foreach ($Component in $Components) {
        Get-DotFilesComponent -Component $Component
    }
}

Function Install-DotFiles {
    <#
        .SYNOPSIS
        Installs the selected dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of enumerated components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is True.
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    Get-DotFilesSettings @PSBoundParameters
}

Function Remove-DotFiles {
    <#
        .SYNOPSIS
        Removes the selected dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of enumerated components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is True.
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    Get-DotFilesSettings @PSBoundParameters
}

Function Get-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.DirectoryInfo]$Component
    )

    $Name             = $Component.Name
    $ScriptName       = $Name + ".ps1"
    $GlobalScriptPath = Join-Path $script:GlobalMetadataPath $ScriptName
    $CustomScriptPath = Join-Path $script:DotFilesMetadataPath $ScriptName

    $Description      = ""
    $Availability     = [PSDotFiles]::NoLogic
    $Installed        = "Unknown"

    if (Test-Path -Path $GlobalScriptPath -PathType Leaf) {
        Write-Debug "Loading global metadata for component: $Name"
        . $GlobalScriptPath
        $MetadataPresent = $true
    }

    if (Test-Path -Path $CustomScriptPath -PathType Leaf) {
        Write-Debug "Loading custom metadata for component: $Name"
        . $CustomScriptPath
        $MetadataPresent = $true
    }

    if ($script:DotFilesAutodetect -or $MetadataPresent) {
        $Availability = Test-DotfilesComponentAvailability -Name $Name
    }

    return [PSCustomObject]@{
        Name         = $Name
        Description  = $Description
        Availability = $Availability
        Installed    = $Installed
    }
}

Function Get-DotFilesSettings {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    if ($Path) {
        $script:DotFilesPath = Test-DotFilesPath -Path $Path
        if (!$script:DotFilesPath) {
            throw "The provided dotfiles path is either not a directory or it can't be accessed."
        }
    } elseif ($global:DotFilesPath) {
        $script:DotFilesPath = Test-DotFilesPath -Path $global:DotFilesPath
        if (!$script:DotFilesPath) {
            throw "The default dotfiles path (`$DotFilesPath) is either not a directory or it can't be accessed."
        }
    } else {
        throw "No dotfiles path was provided and the default dotfiles path (`$DotFilesPath) has not been configured."
    }
    Write-Verbose "Using dotfiles directory: $script:DotFilesPath"

    $script:GlobalMetadataPath = Join-Path $PSScriptRoot "metadata"
    Write-Debug "Using global metadata directory: $script:GlobalMetadataPath"

    $script:DotFilesMetadataPath = Join-Path $script:DotFilesPath "metadata"
    Write-Debug "Using dotfiles metadata directory: $script:DotFilesMetadataPath"

    if ($PSBoundParameters.ContainsKey('Autodetect')) {
        $script:DotFilesAutoDetect = $Autodetect
    } elseif (Test-Path -Path Variable:\DotFilesAutodetect) {
        $script:DotFilesAutoDetect = $global:DotFilesAutodetect
    } else {
        $script:DotFilesAutoDetect = $true
    }
    Write-Debug "Automatic component detection state: $script:DotFilesAutoDetect"
}

Function Get-InstalledPrograms {
    [CmdletBinding()]
    Param()

    $NativeRegPath = "\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $Wow6432RegPath = "\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

    $InstalledPrograms = @(
        # Native applications installed system wide
        Get-ChildItem "HKLM:$NativeRegPath"
        # Native applications installed under the current user
        Get-ChildItem "HKCU:$NativeRegPath"
        # 32-bit applications installed system wide on 64-bit Windows
        if (Test-Path -Path "HKLM:$Wow6432RegPath") { Get-ChildItem "HKLM:$Wow6432RegPath" }
        # 32-bit applications installed under the current user on 64-bit Windows
        if (Test-Path -Path "HKCU:$Wow6432RegPath") { Get-ChildItem "HKCU:$Wow6432RegPath" }
    ) | # Get the properties of each uninstall key
        % { Get-ItemProperty $_.PSPath } |
        # Filter out all of the uninteresting entries
        ? { $_.DisplayName -and
           !$_.SystemComponent -and
           !$_.ReleaseType -and
           !$_.ParentKeyName -and
           ($_.UninstallString -or $_.NoRemove) }

    return $InstalledPrograms
}

Function Test-DotfilesComponentAvailability {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Name
    )

    $Component = $script:InstalledPrograms | ? { $_.DisplayName -like "*$Name*" }
    if ($Component) {
        return [PSDotFiles]::Available
    }
    return [PSDotFiles]::Unavailable
}

Function Test-DotFilesPath {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Path
    )

    if (Test-Path -Path $Path) {
        $PathItem = Get-Item -Path $Path
        if ($PathItem -is [System.IO.DirectoryInfo]) {
            return $PathItem.FullName
        }
    }
    return $false
}

Enum PSDotFiles {
    # The component was successfully detected
    Available            = 0
    # A failure occurred during component detection
    DetectionFailure     = 1
    # The component will be ignored. This is distinct from *Unavailable*
    # as it indicates the component is not available for the platform.
    Ignored              = 10
    # The component will always be installed
    AlwaysInstall        = 11
    # The component will never be installed
    NeverInstall         = 12
    # The component was not detected
    Unavailable          = 13
    # No detection logic was available
    NoLogic              = 20
}
