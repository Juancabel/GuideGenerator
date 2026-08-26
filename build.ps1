<#
.SYNOPSIS
    Builds the PDF. The Windows equivalent of `make`.

.DESCRIPTION
    GNU Make is not installed on Windows by default, so this script does what
    the Makefile does. If you have Make (via Git Bash, WSL, Scoop or winget),
    you can use `make` instead — both produce the same output.

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

# ORDER MATTERS — see the note in the Makefile. crossrefs must run before the
# filters that serialise their own contents to Typst.
$Filters = @(
    'filters/images.lua',
    'filters/crossrefs.lua',
    'filters/listings.lua',
    'filters/tables.lua',
    'filters/callouts.lua'
)

function Test-Dependencies {
    $ok = $true

    $pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
    if ($pandoc) {
        $v = (& pandoc --version | Select-Object -First 1)
        Write-Host "pandoc: $v" -ForegroundColor Green
        $ver = [version](($v -split '\s+')[1] -replace '[^0-9.].*$', '')
        if ($ver -lt [version]'3.0') {
            Write-Host "  WARNING: Pandoc 3.0+ is required for --to=typst." -ForegroundColor Yellow
            $ok = $false
        }
    } else {
        Write-Host "MISSING pandoc  ->  winget install --id JohnMacFarlane.Pandoc" -ForegroundColor Red
        $ok = $false
    }

    $typst = Get-Command typst -ErrorAction SilentlyContinue
    if ($typst) {
        Write-Host "typst:  $(& typst --version)" -ForegroundColor Green
    } else {
        Write-Host "MISSING typst   ->  winget install --id Typst.Typst" -ForegroundColor Red
        $ok = $false
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
    $pandocArgs += "--metadata-file=$(Join-Path $Root 'metadata.yaml')"
    $pandocArgs += "--template=$(Join-Path $Root 'templates/guide.typ')"
    $pandocArgs += '--resource-path=.;img'
    foreach ($f in $Filters) {
        $pandocArgs += "--lua-filter=$(Join-Path $Root $f)"
    }
    $pandocArgs += "--output=$TypFile"

    Write-Host 'Generating Typst source...' -ForegroundColor Cyan
    & pandoc @pandocArgs
    if ($LASTEXITCODE -ne 0) { throw "Pandoc failed with exit code $LASTEXITCODE" }

    if ($TypOnly) {
        Write-Host "Typst source ready: $TypFile" -ForegroundColor Green
        return
    }

    Write-Host 'Compiling Typst -> PDF...' -ForegroundColor Cyan
    & typst compile --root="$Root" "$TypFile" "$PdfFile"
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
