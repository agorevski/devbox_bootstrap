---
name: git-workflow
description: >
  Trigger this skill when a developer asks about git branching, creating PRs,
  rebasing, merging, merge conflicts, stashing, conventional commits,
  cherry-picking, undoing changes, tagging releases, working with remotes,
  or inspecting git history. Also trigger for questions about git aliases
  or git productivity.
triggers:
  - "git help"
  - "how to branch"
  - "create a PR"
  - "rebase my branch"
  - "merge conflict"
  - "git stash"
  - "conventional commit"
  - "cherry pick"
  - "undo commit"
  - "tag release"
  - "git remote"
  - "git log"
  - "git alias"
---

# Git Workflow Skill

A comprehensive, actionable guide for everyday git operations.

---

## 1. Branching Strategies

### Feature Branches (most common)
```bash
# Always branch from the up-to-date default branch
git checkout main && git pull origin main
git checkout -b feature/my-feature

# Push and set upstream in one step
git push -u origin feature/my-feature
```

### Gitflow
```bash
# Main branches: main (production), develop (integration)
git checkout develop && git pull
git checkout -b feature/my-feature develop   # features from develop
git checkout -b release/1.2.0 develop        # releases from develop
git checkout -b hotfix/fix-crash main        # hotfixes from main

# Finish a release: merge into both main AND develop
git checkout main && git merge --no-ff release/1.2.0
git checkout develop && git merge --no-ff release/1.2.0
git branch -d release/1.2.0
```

### Trunk-Based Development
```bash
# Short-lived branches (< 2 days), merge frequently
git checkout -b short/fix-typo
# ... make small, focused change ...
git push -u origin short/fix-typo
# Open PR immediately; delete branch after merge
```

### Branch hygiene
```bash
git branch -d feature/done          # delete merged local branch
git branch -D feature/abandoned     # force-delete unmerged branch
git remote prune origin             # remove stale remote-tracking refs
git fetch --prune                   # fetch + prune in one step
```

---

## 2. Creating Pull Requests (gh CLI)

### Quick PR
```bash
gh pr create --fill          # uses commit messages for title/body
gh pr create --web           # open browser editor
```

### Fully specified PR
```bash
gh pr create \
  --title "feat(auth): add OAuth2 login" \
  --body-file .github/pull_request_template.md \
  --base main \
  --assignee @me \
  --label "enhancement" \
  --reviewer teammate1,teammate2
```

### PR description best practices
- **What**: one sentence summary of the change
- **Why**: motivation / problem being solved
- **How**: key implementation decisions worth calling out
- **Testing**: how you verified it works (screenshots, test output)
- **Breaking changes**: migration steps if any
- Link issues with `Closes #123` or `Fixes #456`

### Useful PR management
```bash
gh pr list                       # list open PRs
gh pr view 42                    # view PR #42
gh pr checkout 42                # check out PR branch locally
gh pr merge 42 --squash --delete-branch
gh pr status                     # PRs involving you
```

---

## 3. Rebasing vs Merging, Squashing

### Merge (preserves history, adds merge commit)
```bash
git checkout main
git merge --no-ff feature/my-feature    # explicit merge commit
git merge --ff-only feature/my-feature  # fast-forward only (fails if not possible)
```

### Rebase (linear history, rewrites commits)
```bash
git checkout feature/my-feature
git rebase main                 # replay feature commits on top of main
git push --force-with-lease     # safe force-push after rebase
```

### Interactive rebase (squash, reorder, edit)
```bash
git rebase -i HEAD~4            # edit last 4 commits
# In editor:
#   pick  abc1234 first commit
#   squash def5678 fixup: typo   ← merge into previous
#   reword ghi9012 another       ← edit message
#   drop  jkl3456 temp debug     ← remove entirely
```

### Squash merge via gh
```bash
gh pr merge 42 --squash --delete-branch
```

### Rule of thumb
| Scenario | Prefer |
|---|---|
| Integrating a finished feature | merge --no-ff |
| Keeping feature branch current | rebase |
| Cleaning up WIP commits | interactive rebase |
| Merging a PR (clean log) | squash merge |

---

## 4. Merge Conflicts

### Identify conflicts
```bash
git status                      # shows "both modified" files
git diff --diff-filter=U        # show only conflicted files
```

### Resolve conflicts
```bash
# 1. Open conflicted file; look for conflict markers:
#    <<<<<<< HEAD
#    your changes
#    =======
#    incoming changes
#    >>>>>>> feature/branch

# 2. Edit the file to desired final state, removing markers

# 3. Stage resolved file
git add path/to/resolved-file

# 4. Continue the operation
git merge --continue            # or: git rebase --continue
```

### Useful merge tools
```bash
git mergetool                   # opens configured visual tool
git checkout --ours   file.txt  # accept your version entirely
git checkout --theirs file.txt  # accept incoming version entirely
```

### Binary file conflicts
```bash
# Binary files can't be text-merged; choose one version explicitly:
git checkout --ours   image.png
git checkout --theirs image.png
git add image.png
```

### Abort a conflicted operation
```bash
git merge --abort
git rebase --abort
git cherry-pick --abort
```

---

## 5. Stashing Work

```bash
git stash                           # stash tracked changes
git stash push -u -m "WIP: login"  # include untracked, with message
git stash list                      # show all stashes
git stash show -p stash@{1}        # show diff of a stash
git stash apply stash@{1}          # apply without removing
git stash pop                       # apply most recent + remove
git stash drop stash@{1}           # delete a specific stash
git stash clear                     # delete ALL stashes
git stash branch feature/new stash@{0}  # create branch from stash
```

---

## 6. Conventional Commits

Format: `<type>(<optional scope>): <description>`

```
feat(auth): add OAuth2 Google login
fix(api): handle null response from payment gateway
chore(deps): bump lodash from 4.17.20 to 4.17.21
docs(readme): update local setup instructions
refactor(db): extract query builder into separate class
test(cart): add edge cases for empty cart checkout
ci(github-actions): cache node_modules between jobs
style(lint): apply prettier formatting to src/
perf(images): lazy-load product thumbnails
revert: feat(auth): add OAuth2 Google login
```

### Breaking changes
```
feat(api)!: remove deprecated /v1/users endpoint

BREAKING CHANGE: Clients must migrate to /v2/users.
See migration guide at docs/migration-v2.md
```

### Commit message body guidelines
- Blank line between subject and body
- Body explains *what* and *why*, not *how*
- Wrap at 72 characters

---

## 7. Cherry-Picking

```bash
git log --oneline other-branch          # find the commit SHA

git cherry-pick abc1234                 # apply single commit
git cherry-pick abc1234 def5678         # apply multiple commits
git cherry-pick abc1234..def5678        # apply a range (exclusive start)
git cherry-pick abc1234^..def5678       # apply a range (inclusive start)

git cherry-pick -n abc1234             # apply changes but don't commit
git cherry-pick --edit abc1234         # apply and edit commit message
```

### If cherry-pick conflicts
```bash
# Resolve conflicts in editor, then:
git add resolved-file
git cherry-pick --continue
# or abort:
git cherry-pick --abort
```

---

## 8. Undoing Changes

### Undo before staging (working tree)
```bash
git restore file.txt                   # discard working tree change
git restore .                          # discard ALL working tree changes
git checkout -- file.txt               # older equivalent
```

### Undo staged changes (keep in working tree)
```bash
git restore --staged file.txt          # unstage a file
git reset HEAD file.txt                # older equivalent
```

### Undo last commit (keep changes staged)
```bash
git reset --soft HEAD~1
```

### Undo last commit (keep changes unstaged)
```bash
git reset HEAD~1                       # default: --mixed
```

### Undo last commit (discard changes entirely)
```bash
git reset --hard HEAD~1                # ⚠️ destructive
```

### Safe undo (creates new "undo" commit — use on shared branches)
```bash
git revert HEAD                        # revert last commit
git revert abc1234                     # revert specific commit
git revert abc1234..def5678            # revert range
```

### Recover a lost commit
```bash
git reflog                             # find the SHA
git checkout -b recovery-branch abc1234
```

---

## 9. Tagging Releases

### Annotated tags (recommended — stored as full git objects)
```bash
git tag -a v1.2.0 -m "Release v1.2.0: add OAuth2 login"
git tag -a v1.2.0 abc1234 -m "Tag specific commit"
```

### Lightweight tags (simple pointer, no metadata)
```bash
git tag v1.2.0-rc1
```

### Push tags
```bash
git push origin v1.2.0          # push single tag
git push origin --tags          # push all tags
```

### Manage tags
```bash
git tag                         # list all tags
git tag -l "v1.*"              # list matching pattern
git show v1.2.0                # show tag details
git tag -d v1.2.0-rc1          # delete local tag
git push origin --delete v1.2.0-rc1  # delete remote tag
```

### GitHub release from tag
```bash
gh release create v1.2.0 \
  --title "v1.2.0: OAuth2 Login" \
  --notes-file CHANGELOG.md \
  dist/app-linux dist/app-macos    # optional assets
```

---

## 10. Working with Remotes

```bash
git remote -v                               # list remotes
git remote add upstream https://github.com/org/repo.git
git remote set-url origin git@github.com:user/repo.git

git fetch origin                            # fetch all branches
git fetch --prune                           # fetch + clean stale refs
git pull                                    # fetch + merge (current branch)
git pull --rebase                           # fetch + rebase (preferred for linear history)
git pull origin main --rebase

git push                                    # push current branch
git push -u origin feature/my-feature      # push + set upstream
git push --force-with-lease                 # safe force-push
git push --force-with-lease=branch:sha     # even safer

# Sync a fork with upstream
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

---

## 11. Git Log & History Inspection

### Viewing history
```bash
git log --oneline --graph --decorate --all  # visual branch graph
git log --oneline -20                       # last 20 commits, compact
git log --author="Alice" --since="2 weeks ago"
git log --grep="fix(auth)"                  # search commit messages
git log -p -- path/to/file.ts              # history of a file with diffs
git log --follow -p -- renamed-file.ts     # follow renames
git shortlog -sn                           # commits per author
```

### Diff
```bash
git diff                          # unstaged changes
git diff --staged                 # staged changes
git diff HEAD~3                   # changes since 3 commits ago
git diff main..feature/branch     # between branches
git diff v1.1.0 v1.2.0            # between tags
git diff --stat                   # summary (files changed, insertions)
git diff --word-diff              # highlight word-level changes
```

### Blame
```bash
git blame file.ts                       # line-by-line authorship
git blame -L 10,25 file.ts             # specific line range
git blame -w file.ts                   # ignore whitespace
git log -S "function login" --oneline  # find when a string was added/removed
```

### Bisect (binary search for a regression)
```bash
git bisect start
git bisect bad                     # current commit is broken
git bisect good v1.1.0             # this tag was working
# git checks out midpoint; test it, then:
git bisect good                    # or: git bisect bad
# repeat until git identifies the first bad commit
git bisect reset                   # return to original HEAD
```

---

## 12. Productivity Git Aliases

Add to `~/.gitconfig` under `[alias]`:

```ini
[alias]
  # Shorthand
  st   = status -sb
  co   = checkout
  br   = branch
  ci   = commit
  df   = diff
  dfs  = diff --staged

  # Pretty log
  lg   = log --oneline --graph --decorate --all
  lp   = log --oneline -20

  # Undo
  undo = reset --soft HEAD~1
  unstage = restore --staged

  # Safe push
  pushf = push --force-with-lease

  # List branches by last commit date
  brd  = branch --sort=-committerdate --format='%(committerdate:short) %(refname:short)'

  # Show what changed in last commit
  last = show --stat HEAD

  # Amend without editing message
  amend = commit --amend --no-edit

  # Stash including untracked
  save = stash push -u -m

  # Show contributors
  who  = shortlog -sn --no-merges

  # Find text across all commits
  find = log -S

  # Prune + fetch
  sync = fetch --prune
```

Apply immediately:
```bash
git config --global alias.lg "log --oneline --graph --decorate --all"
# (or edit ~/.gitconfig directly)
```

---

## 13. Troubleshooting Common Errors

### Detached HEAD
```bash
# Symptom: "You are in 'detached HEAD' state"
git log --oneline -5             # note the SHA you want to keep
git checkout -b rescue/my-work  # create branch to save your commits
# or discard and return:
git checkout main
```

### Diverged branches
```bash
# Symptom: "Your branch and 'origin/main' have diverged"
git fetch origin
git rebase origin/main          # preferred: replay your commits on top
# or merge:
git merge origin/main
```

### Rejected push
```bash
# Symptom: "! [rejected] main -> main (non-fast-forward)"
git pull --rebase               # rebase local commits on top of remote
git push
# If you intentionally rewrote history (e.g., after rebase):
git push --force-with-lease     # safer than --force
```

### Accidentally committed to main
```bash
git branch feature/oops         # save your work on a new branch
git reset --hard origin/main    # reset main back to remote state
git checkout feature/oops       # continue work on correct branch
```

### Large file accidentally committed
```bash
# Remove from history (rewrites history — coordinate with team)
git filter-repo --path bigfile.bin --invert-paths
git push --force-with-lease
```

### Merge conflict with binary files
```bash
git checkout --ours   design.sketch   # keep your version
git checkout --theirs design.sketch   # keep incoming version
git add design.sketch
git merge --continue
```

### "Nothing to commit" but files differ
```bash
git status                       # check for line-ending issues
git config core.autocrlf false  # Windows: disable CRLF conversion
git rm --cached -r .            # clear index
git reset --hard                 # re-read with new settings
```

### Recovering accidentally deleted branch
```bash
git reflog | grep "branch-name"  # find last SHA
git checkout -b branch-name abc1234
```

### Undo a pushed commit safely
```bash
git revert HEAD                  # creates undo commit (safe for shared branches)
git push
```

---

## 14. Signed Commits

### SSH signing (recommended — simplest setup)
```bash
# Configure git to use SSH for signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Sign a single commit
git commit -S -m "feat: add signed feature"

# Verify a signature
git log --show-signature -1
```

### GPG signing
```bash
# List GPG keys
gpg --list-secret-keys --keyid-format=long

# Configure git
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true

# Generate a GPG key if needed
gpg --full-generate-key   # choose RSA 4096, no expiry for convenience

# Export public key (add to GitHub → Settings → SSH and GPG keys)
gpg --armor --export <KEY_ID>
```

### Verify commits on GitHub
Signed commits show a "Verified" badge on GitHub. Configure branch protection
to require signed commits:
```
Settings → Branches → Branch protection rules → Require signed commits
```

---

## 15. Git Worktrees

Worktrees let you check out multiple branches simultaneously in separate
directories — no stashing, no context switching.

```bash
# Create a worktree for a feature branch
git worktree add ../my-feature feature/my-feature

# Create a worktree from a new branch
git worktree add -b hotfix/urgent ../hotfix main

# List all worktrees
git worktree list

# Remove a worktree (after merging)
git worktree remove ../my-feature

# Prune stale worktree entries
git worktree prune
```

### When to use worktrees
- Reviewing a PR while working on your own feature
- Running tests on one branch while coding on another
- Hotfix that can't wait for your current work to be committed
- Comparing behavior between branches side-by-side

---

## 16. Submodules & Sparse Checkout

### Submodules
```bash
# Add a submodule
git submodule add https://github.com/org/lib.git libs/lib

# Clone a repo with submodules
git clone --recurse-submodules https://github.com/org/repo.git

# Initialize submodules after a plain clone
git submodule update --init --recursive

# Update all submodules to latest
git submodule update --remote --merge

# Remove a submodule
git submodule deinit libs/lib
git rm libs/lib
rm -rf .git/modules/libs/lib
```

### Sparse checkout (large monorepos)
```bash
# Enable sparse checkout
git sparse-checkout init --cone

# Only check out specific directories
git sparse-checkout set src/myservice tests/myservice

# Add more directories later
git sparse-checkout add docs/

# List what's checked out
git sparse-checkout list

# Disable (check out everything again)
git sparse-checkout disable
```

---

## 17. .gitattributes

Control line endings, diff behavior, and merge strategies per file type.

```gitattributes
# Auto-detect text files and normalize line endings
* text=auto

# Force LF for source files (cross-platform consistency)
*.cs    text eol=lf
*.py    text eol=lf
*.js    text eol=lf
*.ts    text eol=lf
*.go    text eol=lf
*.rs    text eol=lf
*.sh    text eol=lf
*.yml   text eol=lf
*.yaml  text eol=lf
*.json  text eol=lf
*.md    text eol=lf

# Force CRLF for Windows-only files
*.bat   text eol=crlf
*.cmd   text eol=crlf
*.ps1   text eol=crlf
*.sln   text eol=crlf

# Binary files (don't diff or merge)
*.png   binary
*.jpg   binary
*.gif   binary
*.ico   binary
*.woff2 binary
*.zip   binary
*.exe   binary
*.dll   binary

# Lock files — don't merge, always take the branch version
package-lock.json merge=ours
yarn.lock         merge=ours
```

Place at the repo root. Run `git add --renormalize .` after creating to apply
to existing files.
