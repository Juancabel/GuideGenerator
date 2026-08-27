<#
.SYNOPSIS
    Builds the PDF. The Windows equivalent of `make`.

.DESCRIPTION
    GNU Make is not installed on Windows by default, so this script does what
    the Makefile does. If you have Make (via Git Bash, WSL, Scoop or winget),
    you can use `make` instead - both produce the same output.

    Pandoc and Typst do not have to be on PATH. If they were just installed and
    this shell predates the install, the script reloads PATH from the registry;
    failing that it probes the usual winget, Scoop, Chocolatey and Cargo
    install locations.

.EXAMPLE
    .\build.ps1
    Build the PDF into output\

.EXAMPLE
    .\build.ps1 -Watch
    Rebuild automatically whenever a source file changes.

.EXAMPLE
    .\build.ps1 -Check
    Verify that Pandoc and Typst are installed and new enough.

.EXAMPLE
    .\build.ps1 -Clean
    Delete the output folder.

.EXAMPLE
    .\build.ps1 -TypOnly
    Stop after generating output\*.typ, for debugging the template.
#>

[CmdletBinding()]
param(
    [switch]$Watch,
    [switch]$Check,
    [switch]$Clean,
    [switch]$TypOnly
)

$ErrorActionPreference = 'Stop'

# Architecture adapted from github.com/alexmodrono/typst-pandoc
# (MIT, (c) 2025 Alex). See CREDITS.md.

# Always operate relative to this script, not the caller's location.
$Root      = $PSScriptRoot
$OutputDir = Join-Path $Root 'output'
$DocName   = 'rust-guide'

$TypFile = Join-Path $OutputDir "$DocName.typ"
$PdfFile = Join-Path $OutputDir "$DocName.pdf"

# ORDER MATTERS - see the note in the Makefile. crossrefs must run before the
# filters that serialise their own contents to Typst.
$Filters = @(
    'filters/images.lua',
    'filters/crossrefs.lua',
    'filters/listings.lua',
    'filters/tables.lua',
    'filters/callouts.lua'
)

# Resolved executable paths, filled in by Test-Dependencies.
$script:PandocExe = $null
$script:TypstExe  = $null

# ---------------------------------------------------------------------------
#  Tool discovery
#
#  winget, Scoop and installers write PATH into the registry, but a PowerShell
#  window that was already open keeps the copy it started with. That makes a
#  freshly installed tool look missing until the shell is restarted, which is
#  the single most common reason this script fails. So: look on PATH, then
#  reload PATH from the registry, then probe known install locations.
# ---------------------------------------------------------------------------

function Update-PathFromRegistry {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Join-IfSet {
    # Join-Path throws if the base is null, and several of the environment
    # variables probed below are absent on some Windows configurations
    # (ProgramFiles(x86) on ARM64, for instance) and on non-Windows hosts.
    param([string]$Base, [string]$Child)
    if ([string]::IsNullOrWhiteSpace($Base)) { return $null }
    return (Join-Path $Base $Child)
}

function Resolve-Tool {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string[]]$Probe = @()
    )

    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($cmd) {
        return [pscustomobject]@{ Path = $cmd.Source; OnPath = $true }
    }

    Update-PathFromRegistry
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($cmd) {
        return [pscustomobject]@{ Path = $cmd.Source; OnPath = $false }
    }

    foreach ($candidate in $Probe) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return [pscustomobject]@{ Path = (Resolve-Path -LiteralPath $candidate).Path; OnPath = $false }
        }
    }

    # Last resort: winget keeps unlinked packages under its own store.
    $wingetPackages = Join-IfSet $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if ($wingetPackages -and (Test-Path -LiteralPath $wingetPackages)) {
        $hit = Get-ChildItem -LiteralPath $wingetPackages -Filter "$Name.exe" -Recurse -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) {
            return [pscustomobject]@{ Path = $hit.FullName; OnPath = $false }
        }
    }

    return $null
}

function Get-ToolVersion {
    param([string]$Exe, [string[]]$VersionArgs = @('--version'))
    try {
        $raw = & $Exe @VersionArgs 2>&1 | Select-Object -First 1
        return "$raw".Trim()
    } catch {
        return $null
    }
}

function Get-SemVer {
    param([string]$Text)
    if ($Text -and ($Text -match '(\d+)\.(\d+)(?:\.(\d+))?')) {
        $patch = if ($Matches[3]) { $Matches[3] } else { '0' }
        try { return [version]"$($Matches[1]).$($Matches[2]).$patch" } catch { return $null }
    }
    return $null
}

function Test-Dependencies {
    $ok         = $true
    $pathIssue  = $false

    $pandoc = Resolve-Tool -Name 'pandoc' -Probe @(
        (Join-IfSet $env:LOCALAPPDATA 'Microsoft\WinGet\Links\pandoc.exe'),
        (Join-IfSet $env:ProgramFiles 'Pandoc\pandoc.exe'),
        (Join-IfSet ${env:ProgramFiles(x86)} 'Pandoc\pandoc.exe'),
        (Join-IfSet $env:LOCALAPPDATA 'Pandoc\pandoc.exe'),
        (Join-IfSet $env:USERPROFILE 'scoop\shims\pandoc.exe'),
        (Join-IfSet $env:ProgramData 'chocolatey\bin\pandoc.exe')
    )

    if ($pandoc) {
        $script:PandocExe = $pandoc.Path
        $v   = Get-ToolVersion $pandoc.Path
        $sem = Get-SemVer $v
        Write-Host "pandoc: $v" -ForegroundColor Green
        if (-not $pandoc.OnPath) {
            Write-Host "        found at $($pandoc.Path) - not on this shell's PATH" -ForegroundColor Yellow
            $pathIssue = $true
        }
        if ($sem -and $sem -lt [version]'3.0.0') {
            Write-Host "        ERROR: Pandoc 3.0+ is required for --to=typst (found $sem)." -ForegroundColor Red
            $ok = $false
        }
    } else {
        Write-Host "pandoc: NOT FOUND  ->  winget install --id JohnMacFarlane.Pandoc" -ForegroundColor Red
        $ok = $false
    }

    $typst = Resolve-Tool -Name 'typst' -Probe @(
        (Join-IfSet $env:LOCALAPPDATA 'Microsoft\WinGet\Links\typst.exe'),
        (Join-IfSet $env:USERPROFILE 'scoop\shims\typst.exe'),
        (Join-IfSet $env:USERPROFILE '.cargo\bin\typst.exe'),
        (Join-IfSet $env:ProgramData 'chocolatey\bin\typst.exe')
    )

    if ($typst) {
        $script:TypstExe = $typst.Path
        $v   = Get-ToolVersion $typst.Path
        $sem = Get-SemVer $v
        Write-Host "typst:  $v" -ForegroundColor Green
        if (-not $typst.OnPath) {
            Write-Host "        found at $($typst.Path) - not on this shell's PATH" -ForegroundColor Yellow
            $pathIssue = $true
        }
        if ($sem -and $sem -lt [version]'0.13.0') {
            Write-Host "        ERROR: Typst 0.13+ is required (found $sem)." -ForegroundColor Red
            $ok = $false
        }
    } else {
        Write-Host "typst:  NOT FOUND  ->  winget install --id Typst.Typst" -ForegroundColor Red
        $ok = $false
    }

    if ($pathIssue) {
        Write-Host ''
        Write-Host 'A tool was found but is not on this shell''s PATH. That happens when it' -ForegroundColor Yellow
        Write-Host 'was installed after this window was opened. The build will still work -' -ForegroundColor Yellow
        Write-Host 'this script calls it by full path - but to fix the shell itself, either' -ForegroundColor Yellow
        Write-Host 'open a new PowerShell window or run:' -ForegroundColor Yellow
        Write-Host ''
        Write-Host "  `$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')" -ForegroundColor Cyan
        Write-Host ''
    }

    return $ok
}

function Invoke-Build {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    # Chapters in filename order. The numeric prefixes set the order.
    $contents = Get-ChildItem -Path (Join-Path $Root 'contents') -Filter '*.md' -File |
                Sort-Object Name |
                ForEach-Object { $_.FullName }

    if (-not $contents) {
        throw "No .md files found in contents\"
    }

    $pandocArgs = @()
    $pandocArgs += $contents
    $pandocArgs += '--from=markdown+fenced_divs+bracketed_spans+implicit_figures+table_captions'
    $pandocArgs += '--to=typst'
    # --wrap=none matters: Pandoc's default hard-wraps generated output at
    # ~72 columns, and a wrap point can land inside a multi-word metadata
    # value interpolated into the template (e.g. font-sans: "Segoe UI"),
    # splitting the Typst string literal across two lines and breaking the build.
    $pandocArgs += '--wrap=none'
    $pandocArgs += "--metadata-file=$(Join-Path $Root 'metadata.yaml')"
    $pandocArgs += "--template=$(Join-Path $Root 'templates/guide.typ')"
    $pandocArgs += '--resource-path=.;img'
    foreach ($f in $Filters) {
        $pandocArgs += "--lua-filter=$(Join-Path $Root $f)"
    }
    $pandocArgs += "--output=$TypFile"

    Write-Host 'Generating Typst source...' -ForegroundColor Cyan
    & $script:PandocExe @pandocArgs
    if ($LASTEXITCODE -ne 0) { throw "Pandoc failed with exit code $LASTEXITCODE" }

    if ($TypOnly) {
        Write-Host "Typst source ready: $TypFile" -ForegroundColor Green
        return
    }

    Write-Host 'Compiling Typst -> PDF...' -ForegroundColor Cyan
    & $script:TypstExe compile --root="$Root" "$TypFile" "$PdfFile"
    if ($LASTEXITCODE -ne 0) { throw "Typst failed with exit code $LASTEXITCODE" }

    Write-Host "PDF ready: $PdfFile" -ForegroundColor Green
}

# ---------------------------------------------------------------------------

if ($Check) {
    if (Test-Dependencies) {
        Write-Host "`nAll dependencies present. Run .\build.ps1 to build." -ForegroundColor Green
        exit 0
    }
    exit 1
}

if ($Clean) {
    if (Test-Path $OutputDir) {
        Remove-Item -Recurse -Force $OutputDir
        Write-Host 'Cleaned.' -ForegroundColor Green
    } else {
        Write-Host 'Nothing to clean.'
    }
    exit 0
}

if (-not (Test-Dependencies)) {
    Write-Host "`nInstall the missing tools, then try again. See README.md." -ForegroundColor Yellow
    exit 1
}

Invoke-Build

if ($Watch) {
    Write-Host "`nWatching for changes. Press Ctrl-C to stop." -ForegroundColor Cyan

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $Root
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    # Debounce: editors often fire several events for one save.
    $lastRun = [datetime]::MinValue

    try {
        while ($true) {
            $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)
            if ($change.TimedOut) { continue }

            # Ignore our own build output.
            if ($change.Name -like 'output*') { continue }
            if ($change.Name -notmatch '\.(md|typ|lua|yaml|bib|svg|png|jpg)$') { continue }

            if (([datetime]::Now - $lastRun).TotalMilliseconds -lt 700) { continue }
            $lastRun = [datetime]::Now

            Write-Host "`nChanged: $($change.Name)" -ForegroundColor DarkGray
            try { Invoke-Build } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
        }
    } finally {
        $watcher.Dispose()
    }
}
