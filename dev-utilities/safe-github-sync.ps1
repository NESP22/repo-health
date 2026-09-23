# Safe GitHub sync — Windows (PowerShell). Night-safe: fetch + classify by default.
# Replaces the unsafe C:\Projects\sync-all.ps1. Zero destructive operations.
# Mutations are opt-in ONLY: -FF (fast-forward clean, strictly-behind, non-protected
# repos) and -Push (push clean, strictly-ahead, non-protected repos).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File safe-github-sync.ps1          # audit only
#   powershell -ExecutionPolicy Bypass -File safe-github-sync.ps1 -FF      # fast-forward safe repos
#   powershell -ExecutionPolicy Bypass -File safe-github-sync.ps1 -Push    # push safe repos
param(
  [switch]$FF,
  [switch]$Push
)

$ErrorActionPreference = 'SilentlyContinue'
$env:GIT_TERMINAL_PROMPT = '0'

# Repos that are NEVER mutated by -FF / -Push, regardless of state.
$Protected = @(
  'team-hub-app',               # Team Hub (global hold on opponent intel/scouting)
  'nesp_email_reply_assistant', # Email Assistant
  'nesp-crm',                   # CRM-AI
  'ShiftFrame',                 # shiftframe-hockey
  'shiftframe-hockey'
)

$roots = @('C:\Projects', 'C:\Users\cedwards\ShiftFrameWindowsDev')
$repos = New-Object System.Collections.Generic.List[string]
foreach ($r in $roots) {
  if (Test-Path $r) {
    foreach ($d in Get-ChildItem -Directory $r) {
      if (Test-Path "$($d.FullName)\.git") { $repos.Add($d.FullName) }
    }
  }
}

foreach ($d in $repos) {
  $name = Split-Path $d -Leaf
  Push-Location $d
  $branch = (git rev-parse --abbrev-ref HEAD 2>$null); if (-not $branch) { $branch = '(detached)' }
  $remote = (git remote get-url origin 2>$null)
  if (-not $remote) { "{0,-28} NO-REMOTE" -f $name; Pop-Location; continue }

  git fetch origin --no-tags 2>$null
  if ($LASTEXITCODE -ne 0) { "{0,-28} ERROR fetch failed" -f $name; Pop-Location; continue }

  $up = (git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
  if (-not $up) { "{0,-28} {1,-26} NO-UPSTREAM" -f $name, $branch; Pop-Location; continue }

  $ahead  = [int](git rev-list --count "HEAD...$up" --left-only 2>$null)
  $behind = [int](git rev-list --count "HEAD...$up" --right-only 2>$null)
  $dirty  = [int]((git status --porcelain 2>$null | Where-Object { $_ -notmatch '^\?\? ' }).Count)
  $prot   = $Protected -contains $name

  $class = 'CURRENT'
  if ($dirty -gt 0) { $class = 'LOCAL CHANGES' }
  elseif ($ahead -gt 0 -and $behind -gt 0) { $class = 'DIVERGED' }
  elseif ($ahead -gt 0) { $class = 'PUSH NEEDED' }
  elseif ($behind -gt 0) { $class = 'PULL SAFE' }

  $tag = ''
  if ($prot) { $tag = ' [PROTECTED]' }

  "{0,-28} {1,-26} {2,-13} ahead={3,-3} behind={4,-3} dirty={5,-3}{6}" -f $name, $branch, $class, $ahead, $behind, $dirty, $tag

  # --- Opt-in mutations only ---
  if ($prot) { Pop-Location; continue }

  if ($FF -and $class -eq 'PULL SAFE') {
    git pull --ff-only 2>$null
    if ($LASTEXITCODE -eq 0) { "    -> fast-forwarded to $((git log -1 --format=%h 2>$null))" }
    else { "    -> ff-only pull skipped/failed (left alone)" }
  }
  if ($Push -and $class -eq 'PUSH NEEDED') {
    git push origin $branch 2>$null
    if ($LASTEXITCODE -eq 0) { "    -> pushed $branch" }
    else { "    -> push failed (left alone)" }
  }
  Pop-Location
}
