# Syncing these dotfiles (pull & push)

How to keep this repo in sync across machines (Windows PowerShell + Git Bash,
WSL/Linux, macOS). The same commands work everywhere; the aliases below are
defined in `lib/common_shell` and available in every shell that sources it.

## The short version

```bash
c                       # cd ~/code (then: cd dotfiles)
gst                     # git status  — see what changed
gaa                     # git add -A  — stage everything
git commit -m "..."     # commit (or use the AI helper: tools/cldcmt)
gpl                     # git pull    — fetch + merge remote first
gph                     # git push; git push --tags
```

If `gpl` reports conflicts, jump to [Resolving conflicts](#resolving-conflicts).

## Git aliases (from `lib/common_shell`)

| Alias   | Command                          | Use                                  |
|---------|----------------------------------|--------------------------------------|
| `gst`   | `git status`                     | What changed                         |
| `gd`    | `git diff`                       | Review unstaged changes              |
| `gaa`   | `git add -A`                     | Stage everything (also `gada`)       |
| `gad`   | `git add`                        | Stage specific files                 |
| `glg`   | `git log`                        | History                              |
| `gpl`   | `git pull`                       | Fetch + merge remote                 |
| `gplrb` | `git pull --rebase`              | Pull, replaying your commits on top  |
| `gph`   | `git push; git push --tags`      | Push commits and tags                |
| `gpsh`  | `git push --no-verify` (no tests)| Push, skipping pre-push hooks        |
| `gphf`  | `git push -f; git push -f --tags`| Force push (careful)                 |
| `gco`   | `git checkout`                   | Switch branch / restore file         |
| `gmm`   | `git merge master`               | Merge master into current branch     |

There's no commit alias — use `git commit -m "..."`, or the AI commit helpers in
[`tools/`](tools/README.md): `cldcmt` (commit), `cldgcmep "msg"` (add + fix +
commit + push).

## Normal sync (no conflicts)

Do this whenever you sit down at a machine, and again before you push:

```bash
gst                     # confirm what's local
gaa && git commit -m "describe your change"
gpl                     # pull remote changes (fast-forward or auto-merge)
gph                     # push
```

**Always `gpl` before `gph`.** If the remote moved on and you push without
pulling, git rejects the push (`non-fast-forward`). Pull first, resolve if
needed, then push.

Prefer `gplrb` (`git pull --rebase`) if you want your local commits replayed on
top of the remote instead of creating a merge commit — keeps history linear.

## Resolving conflicts

When `gpl` can't merge cleanly (common here because Windows and Linux both edit
the shared shell/profile files), git stops and marks the conflicts:

```bash
gst                                 # files listed as "both modified" (UU)
git diff --name-only --diff-filter=U   # just the conflicted files
```

Open each conflicted file and look for the markers:

```
<<<<<<< HEAD
your local version
=======
the incoming remote version
>>>>>>> origin/master
```

Edit to the version you want — **usually keep both sides** when the two edits are
independent additions (e.g. one machine added btop wrappers, the other added
nvim setup). Delete all three marker lines. Then:

```bash
gaa                                 # stage the resolved files
git commit --no-edit                # complete the merge commit
gph                                 # push
```

To bail out and start over: `git merge --abort` (or `git rebase --abort` /
`grba` if you were rebasing).

### After resolving, sanity-check before pushing

These are dotfiles — a broken shell config bites every new terminal. Verify the
files still parse:

```bash
# bash configs
for f in lib/common_shell lib/winbashrc bashrc bash_profile; do bash -n "$f" && echo "OK $f"; done

# Full shell-config and reload-safety check
tools/test-shell-config.sh

# Enable the repository hook once per clone
git config core.hooksPath .githooks

# PowerShell files (run in PowerShell)
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\windows\profile.ps1).Path, [ref]$null, [ref]$null)
```

Two gotchas that bite on Windows specifically:
- **Alias-vs-function collisions.** Git for Windows sets `alias node='winpty
  node.exe'`; a later `node() { ... }` then fails to parse. `common_shell`
  `unalias`es `nvm node npm npx` before defining the lazy-load functions. Keep
  that line.
- **Non-ASCII in `.ps1` files.** Windows PowerShell 5.1 mis-parses `•`, `→`, `—`
  when the file has no UTF-8 BOM. Stick to ASCII in PowerShell scripts, or save
  with a BOM.

## First-time setup on a new machine

```bash
cd ~/code && git clone git@github.com:lee101/dotfiles.git   # or https://...
cd dotfiles
# Windows: run quick-setup-windows.ps1 from PowerShell (see WINDOWS_QUICK_START.md)
# Linux/macOS: source the bashrc / run the linker
```

See `WINDOWS_QUICK_START.md` / `WINDOWS_SETUP.md` for the Windows bootstrap.
