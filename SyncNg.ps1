# Steps through the template's files and offers to copy each one that differs into a sibling repo, renamed for it.
# Usage: Sync-Ng ConsideraWeb.Ng.Some.Name [-Reverse] [-Force]
#   -Reverse  copy from the repo back into the template, turning the repo's names back into the template's
#   -Force    run even when either repo has uncommitted changes
# Both repos must be clean (nothing to commit) so that, at the end, git diff shows exactly what this run changed.
# The template's placeholder names (ConsideraWeb.Ng.Template, 4299, ...) are swapped for the repo's own names before
# comparing, so diffs only show real changes. The repo's names are read from its package.json, angular.json and
# src/index.html, and shown first so they can be checked or corrected. Files in .templateignore are skipped, and files
# that exist only on the receiving side are left alone. Line-ending-only differences don't count. For each file that differs it shows a diff and asks:
#   y  copy it    n  skip it    f  skip the rest of this folder    i  never sync it    c  open the diff in VS Code    q  stop
# "never sync it" adds a sync: line for the file to .templateignore, so later syncs skip it in both directions while
# Create-Ng still copies it into new apps (use it for files every app makes its own, like app.component.html).
param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [switch]$Reverse,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$template = $PSScriptRoot.TrimEnd('\')
$target = if ([IO.Path]::IsPathRooted($Repo)) { $Repo.TrimEnd('\') } else { Join-Path (Split-Path $template) $Repo }
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw "$target does not exist." }
$repoName = Split-Path $target -Leaf

# Runs git in $root. safe.directory=* lets git read repos owned by another account (e.g. Administrators), and
# core.safecrlf=false hides the "LF will be replaced by CRLF" warnings.
function Invoke-Git([string]$root) {
    $ErrorActionPreference = 'Continue'
    git -c safe.directory=* -c core.safecrlf=false -C $root @args
}

# Stops unless both repos have nothing to commit, so the closing git diff shows only this run's changes.
if (-not $Force) {
    $dirty = $false
    foreach ($root in $template, $target) {
        $status = @(Invoke-Git $root status --porcelain 2>$null)
        if ($LASTEXITCODE -ne 0) { throw "$root is not a git repo." }
        if ($status.Count) {
            Write-Host "$(Split-Path $root -Leaf) has uncommitted changes:" -ForegroundColor Red
            $status | ForEach-Object { Write-Host "  $_" }
            $dirty = $true
        }
    }
    if ($dirty) {
        Write-Host 'Commit or stash them first (or run again with -Force).' -ForegroundColor Red
        exit 1
    }
}

# --- Ignore list -----------------------------------------------------------------------------------------------------

$ignorePath = Join-Path $template '.templateignore'
$ignore = Get-Content -LiteralPath $ignorePath |
    ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
# "sync: <path>" lines name one exact file (as it is named in the template) that is never synced, but is still copied
# into new apps. Every other line is a name matched anywhere, which Create-Ng skips too.
$syncOnly = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$ignore | Where-Object { $_ -match '^sync:\s*(.+)$' } | ForEach-Object { [void]$syncOnly.Add($Matches[1].Trim()) }
$ignore = @($ignore | Where-Object { $_ -notmatch '^sync:' })
$ignoreDirs = @($ignore | Where-Object { $_.EndsWith('/') } | ForEach-Object { $_.TrimEnd('/') })
$ignoreFiles = @($ignore | Where-Object { -not $_.EndsWith('/') })

# Adds a sync: line for $templateRel to .templateignore, under its own heading the first time.
function Add-SyncIgnore([string]$templateRel) {
    $text = [IO.File]::ReadAllText($ignorePath)
    $heading = '# Never synced by Sync-Ng (Create-Ng still copies these into new apps)'
    $add = if ($text -match [regex]::Escape($heading)) { '' } else { "`n$heading`n" }
    if ($text.Length -and -not $text.EndsWith("`n")) { $add = "`n$add" }
    [IO.File]::AppendAllText($ignorePath, "${add}sync: $templateRel`n", (New-Object Text.UTF8Encoding $false))
    [void]$syncOnly.Add($templateRel)
}

# True when the file's name, or any folder on its path, is in .templateignore (same matching as robocopy /XF and /XD).
function Test-Ignored([string]$rel) {
    $parts = $rel -split '/'
    foreach ($pattern in $ignoreFiles) { if ($parts[-1] -like $pattern) { return $true } }
    foreach ($dir in ($parts | Select-Object -SkipLast 1)) {
        foreach ($pattern in $ignoreDirs) { if ($dir -like $pattern) { return $true } }
    }
    return $false
}

# Files under $root as forward-slash relative paths: what git tracks plus untracked files it doesn't ignore, or every
# file when $root isn't a repo.
function Get-RelativeFiles([string]$root) {
    $list = Invoke-Git $root ls-files --cached --others --exclude-standard 2>$null
    if ($LASTEXITCODE -ne 0) {
        $list = Get-ChildItem -LiteralPath $root -Recurse -File -Force |
            ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') }
    }
    $list | Where-Object { -not (Test-Ignored $_) -and (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf) } |
        Sort-Object
}

# --- Renames ---------------------------------------------------------------------------------------------------------

# Best-effort reads of the repo's names; anything that can't be read comes back empty and can be typed in.
function Read-RepoValue([scriptblock]$read) { try { [string](& $read) } catch { '' } }
$project = Read-RepoValue { (Get-Content -LiteralPath (Join-Path $target 'package.json') -Raw | ConvertFrom-Json).name }
$serve = $null
try {
    $serve = (Get-Content -LiteralPath (Join-Path $target 'angular.json') -Raw | ConvertFrom-Json).projects.$project.architect.serve.options
} catch {}
$app = Read-RepoValue { $serve.servePath.Trim('/') }
$port = Read-RepoValue { $serve.port }
$title = Read-RepoValue {
    if ((Get-Content -LiteralPath (Join-Path $target 'src/index.html') -Raw) -match '<title>(.*?)</title>') { $Matches[1] }
}

# Same pairs as Create-Ng.bat. Lock marks the one rename also applied to package-lock.json.
$rules = [Collections.ArrayList]@(
    [pscustomobject]@{ What = 'repo folder'; Template = 'ConsideraWeb.Ng.Template'; Repo = $repoName; Lock = $false },
    [pscustomobject]@{ What = 'npm/Angular project'; Template = 'consideraweb-ng-template'; Repo = $project; Lock = $true },
    [pscustomobject]@{ What = 'page title'; Template = 'ConsideraWeb Template'; Repo = $title; Lock = $false },
    [pscustomobject]@{ What = 'URL path'; Template = '/template/'; Repo = $(if ($app) { "/$app/" } else { '' }); Lock = $false },
    [pscustomobject]@{ What = 'dev server port'; Template = '4299'; Repo = $port; Lock = $false }
)

# The template's files use placeholder names. Each file is renamed for the receiving side before it's compared, so a
# diff only shows real changes. The repo's names are read from the repo above; this lets you check or correct them.
Write-Host ''
if ($Reverse) {
    Write-Host "Syncing $repoName -> template" -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Before comparing, $repoName's own names are swapped back to the template's placeholders,"
} else {
    Write-Host "Syncing template -> $repoName" -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Before comparing, the template's placeholder names are swapped for $repoName's own names,"
}
Write-Host 'so the diffs only show real changes. These were read from the repo and are normally right.'
while ($true) {
    Write-Host ''
    for ($i = 0; $i -lt $rules.Count; $i++) {
        $r = $rules[$i]
        $repoText = if ($r.Repo) { $r.Repo } else { '(not found, left as is)' }
        $from, $to = if ($Reverse) { $repoText, $r.Template } else { $r.Template, $repoText }
        Write-Host ('  {0}  {1,-20} {2,-30} -> {3}' -f ($i + 1), $r.What, $from, $to)
    }
    Write-Host ''
    $answer = Read-Host 'Look right? Enter to start, or a number to correct that line, or a to add a swap'
    if (-not $answer -or $answer -eq 'y') { break }
    if ($answer -eq 'a') {
        $templateText = Read-Host '  Text as it appears in the template'
        $repoText = Read-Host "  Same text as it appears in $repoName"
        if ($templateText -and $repoText) {
            [void]$rules.Add([pscustomobject]@{ What = 'extra'; Template = $templateText; Repo = $repoText; Lock = $false })
        }
    } elseif ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $rules.Count) {
        $r = $rules[[int]$answer - 1]
        $value = Read-Host "  $repoName's $($r.What) (Enter keeps '$($r.Repo)')"
        if ($value) { $r.Repo = $value }
    }
}

# Each rename as (from, to) in the sync direction, longest first so one rename never eats part of a longer one.
$pairs = @($rules | Where-Object { $_.Template -and $_.Repo } | ForEach-Object {
    if ($Reverse) { [pscustomobject]@{ From = $_.Repo; To = $_.Template; Lock = $_.Lock } }
    else { [pscustomobject]@{ From = $_.Template; To = $_.Repo; Lock = $_.Lock } }
} | Sort-Object { $_.From.Length } -Descending)

function Rename-Text([string]$text, [bool]$lockFile) {
    foreach ($p in $pairs) { if (-not $lockFile -or $p.Lock) { $text = $text.Replace($p.From, $p.To) } }
    $text
}

# --- Diff ------------------------------------------------------------------------------------------------------------

$binary = '\.(ico|png|jpe?g|gif|webp|woff2?|ttf|eot)$'
$maxLines = 150
$utf8 = New-Object Text.UTF8Encoding $false

# Prints git's diff of $old -> $new in colour, without git's file headers, cut off after $maxLines lines.
function Show-Diff([string]$old, [string]$new) {
    $ErrorActionPreference = 'Continue'
    $lines = @(git diff --no-index --no-color --ignore-cr-at-eol -- $old $new 2>$null)
    $inHunk = $false
    $shown = 0
    foreach ($line in $lines) {
        if (-not $inHunk) { if ($line.StartsWith('@@')) { $inHunk = $true } else { continue } }
        if ($shown -ge $maxLines) {
            Write-Host "  ... $($lines.Count - $shown) more lines (c to see it all in VS Code)" -ForegroundColor DarkGray
            break
        }
        $colour = switch -Wildcard ($line) { '+*' { 'Green' } '-*' { 'Red' } '@@*' { 'Cyan' } default { 'Gray' } }
        Write-Host "  $line" -ForegroundColor $colour
        $shown++
    }
}

function Show-NewFile([string]$text) {
    $lines = $text -split "`r?`n"
    $lines | Select-Object -First $maxLines | ForEach-Object { Write-Host "  +$_" -ForegroundColor Green }
    if ($lines.Count -gt $maxLines) { Write-Host "  ... $($lines.Count - $maxLines) more lines" -ForegroundColor DarkGray }
}

# --- Sync ------------------------------------------------------------------------------------------------------------

$src = if ($Reverse) { $target } else { $template }
$dst = if ($Reverse) { $template } else { $target }
$staging = Join-Path ([IO.Path]::GetTempPath()) "Sync-Ng-$PID"
New-Item -ItemType Directory -Force $staging | Out-Null
$question = if ($Reverse) { 'Copy to template?' } else { 'Copy from template?' }
$skippedDirs = @{}
$copied = 0; $skipped = 0; $same = 0; $neverSync = 0

try {
    foreach ($rel in (Get-RelativeFiles $src)) {
        $dir = if ($rel.Contains('/')) { $rel.Substring(0, $rel.LastIndexOf('/')) } else { '' }
        if ($skippedDirs.Keys | Where-Object { $dir -eq $_ -or $dir.StartsWith("$_/") }) { $skipped++; continue }

        $srcPath = Join-Path $src $rel
        $dstRel = Rename-Text $rel $false
        # sync: lines name the file as it is named in the template, whichever way this run goes.
        $templateRel = if ($Reverse) { $dstRel } else { $rel }
        if ($syncOnly.Contains($templateRel)) { continue }
        $dstPath = Join-Path $dst $dstRel
        $exists = Test-Path -LiteralPath $dstPath -PathType Leaf
        $isBinary = $rel -match $binary

        # The incoming file, renamed for its destination and staged under its own name so diffs keep the right syntax.
        $incoming = Join-Path $staging (Split-Path $dstRel -Leaf)
        if ($isBinary) {
            Copy-Item -LiteralPath $srcPath $incoming -Force
            if ($exists -and (Get-FileHash -LiteralPath $srcPath).Hash -eq (Get-FileHash -LiteralPath $dstPath).Hash) { $same++; continue }
        } else {
            $text = Rename-Text ([IO.File]::ReadAllText($srcPath)) ((Split-Path $rel -Leaf) -eq 'package-lock.json')
            [IO.File]::WriteAllText($incoming, $text, $utf8)
            if ($exists -and $text.Replace("`r`n", "`n") -ceq [IO.File]::ReadAllText($dstPath).Replace("`r`n", "`n")) { $same++; continue }
        }

        Write-Host ''
        $label = if ($dstRel -ne $rel) { "$rel -> $dstRel" } else { $rel }
        if (-not $exists) { Write-Host "=== $label (new)" -ForegroundColor Yellow }
        else { Write-Host "=== $label (changed)" -ForegroundColor Yellow }
        if ($isBinary) { Write-Host '  binary file differs' -ForegroundColor DarkGray }
        elseif ($exists) { Show-Diff $dstPath $incoming }
        else { Show-NewFile $text }

        while ($true) {
            $answer = (Read-Host "$question [y]es [n]o [f] skip folder [i] never sync [c] VS Code diff [q]uit").ToLower()
            if ($answer -eq 'c') {
                if ($exists) { & code --diff $dstPath $incoming } else { & code $incoming }
                continue
            }
            if ($answer -in 'y', 'n', 'f', 'i', 'q') { break }
        }
        if ($answer -eq 'i') {
            Add-SyncIgnore $templateRel
            Write-Host "  added 'sync: $templateRel' to .templateignore; it won't be offered again" -ForegroundColor DarkYellow
            $neverSync++
        }
        if ($answer -eq 'q') { break }
        if ($answer -eq 'y') {
            New-Item -ItemType Directory -Force (Split-Path $dstPath) | Out-Null
            Copy-Item -LiteralPath $incoming $dstPath -Force
            Write-Host "  copied" -ForegroundColor Green
            $copied++
        } else {
            if ($answer -eq 'f') { $skippedDirs[$dir] = $true }
            $skipped++
        }
    }
} finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Done: $copied copied, $skipped skipped, $same already the same." -ForegroundColor Cyan
if ($neverSync) {
    Write-Host "$neverSync file(s) added to .templateignore as never synced. Commit that change in the template." -ForegroundColor DarkYellow
}

# Everything uncommitted in the receiving repo is from this run (it started clean, unless -Force).
if ($copied) {
    Write-Host ''
    Write-Host "git diff in $(Split-Path $dst -Leaf):" -ForegroundColor Cyan
    Invoke-Git $dst --no-pager diff --color=always
    $new = @(Invoke-Git $dst ls-files --others --exclude-standard)
    if ($new.Count) {
        Write-Host 'New files:' -ForegroundColor Cyan
        $new | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    }
}
