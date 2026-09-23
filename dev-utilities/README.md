# Safe GitHub Sync Tooling

Night-safe, audit-first repo sync utilities for the NESP22 machines
(Windows THEBOSS and macOS). These replace the retired `C:\Projects\sync-all.ps1`,
which deleted live `.git/*.lock` files, switched branches, pulled, and deleted
merged branches — unsafe while overnight agents are running.

## Guarantees

Both scripts, in their default mode, are **read-only**: they `git fetch` (remote-tracking
refs only) and classify each repo. They **never** commit, stash, reset, clean, force,
checkout, delete branches, delete lock files, or overwrite local files.

The only mutations are strictly opt-in via an explicit flag, and each is gated on the
repo being clean, non-protected, and in the exact right state:

- `-FF` / `--ff`  — `git pull --ff-only`, ONLY for `PULL SAFE` repos (clean, strictly behind).
- `-Push` / `--push` — `git push origin <branch>`, ONLY for `PUSH NEEDED` repos (clean, strictly ahead).

Protected repos are never mutated by any flag.

## Classifications

| Class | Meaning |
|---|---|
| `CURRENT` | clean, ahead=0 and behind=0 vs its upstream |
| `PULL SAFE` | clean, strictly behind (fast-forward available) |
| `PUSH NEEDED` | clean, strictly ahead (local commits unpushed) |
| `LOCAL CHANGES` | tracked working-tree changes present |
| `DIVERGED` | ahead AND behind (history split — needs manual handling) |
| `ERROR` / `NO-UPSTREAM` / `NO-REMOTE` | fetch failed / no tracking branch / no origin |

Dirty is measured on *tracked* changes only; untracked paths (e.g. `.worktrees/`) do not
flag a repo dirty because they cannot block a fast-forward or a push.

## Protected repos

Never mutated, regardless of state:

- `team-hub-app` (global hold on opponent intel / scouting)
- `nesp_email_reply_assistant`
- `nesp-crm` (CRM-AI)
- `ShiftFrame` / `shiftframe-hockey`

## Usage

Windows (PowerShell 5.1+):

```powershell
powershell -ExecutionPolicy Bypass -File safe-github-sync.ps1        # audit only
powershell -ExecutionPolicy Bypass -File safe-github-sync.ps1 -FF    # fast-forward safe repos
powershell -ExecutionPolicy Bypass -File safe-github-sync.ps1 -Push  # push safe repos
```

macOS (bash):

```bash
bash safe-github-sync.sh            # audit only
bash safe-github-sync.sh --ff       # fast-forward safe repos
bash safe-github-sync.sh --push     # push safe repos
```

Clone roots are `C:\Projects` (plus `ShiftFrameWindowsDev`) on Windows and `~/Projects`
on macOS.
