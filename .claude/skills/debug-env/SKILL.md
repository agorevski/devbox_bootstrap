---
name: debug-env
description: >
  Diagnose and fix broken Windows 11 developer environments set up via devbox_bootstrap.
  Covers winget, Git, Docker Desktop, Node.js/nvm, Python, .NET SDK, WSL2, VS Code,
  PowerShell, Azure CLI, PATH corruption, and corporate SSL/proxy issues.
triggers:
  - "debug my environment"
  - "fix my dev environment"
  - "my tools are broken"
  - "environment issues"
  - "fix my setup"
  - "tool not working"
  - "command not found"
  - "PATH issues"
  - "dev environment broken"
---

# Skill: Debug Windows Developer Environment

## Overview

This skill helps diagnose and fix broken developer tooling on Windows 11 machines
bootstrapped with `devbox_bootstrap` (winget-based setup covering Azure CLI, .NET,
Python, Node.js, Docker Desktop, Kubernetes tooling, and more).

**General approach:**
1. Run the Quick Diagnostic to identify broken tools.
2. Jump to the relevant section for targeted fixes.
3. Prefer targeted fixes over full reinstalls.
4. Escalate to reinstall only when config is corrupted beyond repair.

---

## 1. Quick Diagnostic

Run this block in an **elevated PowerShell** session to get a snapshot of the environment.

```powershell
Write-Host "=== System ===" -ForegroundColor Cyan
[System.Environment]::OSVersion.VersionString
(Get-ComputerInfo).WindowsProductName

Write-Host "`n=== Tool Versions ===" -ForegroundColor Cyan
$tools = @{
    "winget"     = { winget --version }
    "git"        = { git --version }
    "node"       = { node --version }
    "npm"        = { npm --version }
    "python"     = { python --version }
    "pip"        = { pip --version }
    "dotnet"     = { dotnet --version }
    "docker"     = { docker --version }
    "kubectl"    = { kubectl version --client --short }
    "helm"       = { helm version --short }
    "az"         = { az --version 2>&1 | Select-Object -First 1 }
    "code"       = { code --version 2>&1 | Select-Object -First 1 }
    "pwsh"       = { pwsh --version }
    "ssh"        = { ssh -V }
    "wsl"        = { wsl --version 2>&1 | Select-Object -First 1 }
}
foreach ($tool in $tools.GetEnumerator()) {
    try {
        $ver = & $tool.Value 2>&1
        Write-Host "  $($tool.Key.PadRight(10)) : $ver" -ForegroundColor Green
    } catch {
        Write-Host "  $($tool.Key.PadRight(10)) : NOT FOUND" -ForegroundColor Red
    }
}

Write-Host "`n=== PATH entries ===" -ForegroundColor Cyan
$env:PATH -split ";" | Where-Object { $_ } | ForEach-Object { "  $_" }

Write-Host "`n=== Docker ===" -ForegroundColor Cyan
try { docker info 2>&1 | Select-String "Server Version|OS/Arch|Warnings" } catch { "  Docker daemon unreachable" }

Write-Host "`n=== WSL Distros ===" -ForegroundColor Cyan
wsl --list --verbose 2>&1
```

**Interpreting output:**
- `NOT FOUND` → tool missing from PATH or not installed; see the relevant section below.
- Docker daemon unreachable → Docker Desktop not running or WSL2 backend broken.
- Duplicate PATH entries → PATH bloat; see Section 12.

---

## 2. winget Issues

### winget Not Found

```powershell
# Check if App Installer is installed
Get-AppxPackage -Name Microsoft.DesktopAppInstaller

# If missing, install from Microsoft Store or sideload:
# https://aka.ms/getwinget
# Or via PowerShell (requires internet):
$url = "https://aka.ms/getwinget"
Start-Process $url
```

### winget Installation Fails

```powershell
# Check winget source health
winget source list
winget source reset --force

# Clear winget cache
Remove-Item "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalCache\*" -Recurse -Force -ErrorAction SilentlyContinue

# Retry with verbose output
winget install --id <PackageId> --verbose-logs

# View logs
$logPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
Get-ChildItem $logPath | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

### winget Update Issues

```powershell
# Upgrade all packages
winget upgrade --all --accept-source-agreements --accept-package-agreements

# If a specific package is stuck
winget uninstall --id <PackageId>
winget install --id <PackageId>
```

**Escalate to reinstall when:** App Installer itself is corrupted; reinstall from the Microsoft Store.

---

## 3. Git Problems

### git Not Found

```powershell
# Check if installed but not on PATH
Get-Command git -ErrorAction SilentlyContinue
Get-Item "C:\Program Files\Git\cmd\git.exe" -ErrorAction SilentlyContinue

# Add Git to PATH for current session
$env:PATH += ";C:\Program Files\Git\cmd"

# Permanently fix (user-level)
[System.Environment]::SetEnvironmentVariable(
    "PATH",
    [System.Environment]::GetEnvironmentVariable("PATH","User") + ";C:\Program Files\Git\cmd",
    "User"
)

# Reinstall via winget if binary is missing
winget install --id Git.Git --source winget
```

### Authentication / Credential Manager

```powershell
# Check configured credential helper
git config --global credential.helper

# Reset to Windows Credential Manager
git config --global credential.helper manager

# Clear cached credentials (forces re-auth)
cmdkey /list | Select-String "git" | ForEach-Object {
    $target = ($_ -split "Target: ")[1].Trim()
    cmdkey /delete:$target
}

# For GitHub with PAT: use Git Credential Manager
winget install --id GitHub.GitCredentialManager
```

### SSH Key Setup

```powershell
# Generate Ed25519 key
ssh-keygen -t ed25519 -C "your_email@example.com" -f "$env:USERPROFILE\.ssh\id_ed25519"

# Start ssh-agent and add key
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add "$env:USERPROFILE\.ssh\id_ed25519"

# Test GitHub connectivity
ssh -T git@github.com

# If ssh-agent service is missing (not a Windows 10+ feature), install OpenSSH:
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

### git Config Issues

```powershell
# Show effective config
git config --list --show-origin

# Fix line ending issues (Windows standard)
git config --global core.autocrlf true

# Fix SSL certificate errors (corporate proxy — see Section 13 first)
git config --global http.sslVerify false  # LAST RESORT ONLY
```

---

## 4. Docker Desktop Issues

### Docker Desktop Not Running

```powershell
# Check if process is running
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue

# Start Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait and test (retry up to 30s)
$i = 0; while ($i -lt 6) { Start-Sleep 5; try { docker info | Out-Null; "Docker ready"; break } catch {}; $i++ }
```

### WSL2 Backend Problems

```powershell
# Verify WSL2 is the default
wsl --set-default-version 2

# Check WSL2 kernel version
wsl --status

# Update WSL2 kernel
wsl --update

# Restart WSL
wsl --shutdown
# Then restart Docker Desktop

# If docker-desktop distro is broken
wsl --unregister docker-desktop
wsl --unregister docker-desktop-data
# Restart Docker Desktop — it will recreate them
```

### Disk Space Issues

```powershell
# Find Docker's virtual disk
$vhd = "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx"
Get-Item $vhd | Select-Object Name, @{N="SizeGB";E={[math]::Round($_.Length/1GB,2)}}

# Prune Docker resources (removes unused images, containers, volumes)
docker system prune -af --volumes

# Compact the VHDX (run in admin PowerShell, Docker must be stopped)
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
wsl --shutdown
Optimize-VHD -Path $vhd -Mode Full
```

### Reset Docker Desktop

```powershell
# Soft reset (preserves images): Settings → Troubleshoot → Restart Docker
# Hard reset (removes everything): Settings → Troubleshoot → Reset to factory defaults

# Via CLI equivalent (removes all data):
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
wsl --unregister docker-desktop 2>$null
wsl --unregister docker-desktop-data 2>$null
Remove-Item "$env:APPDATA\Docker" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Docker" -Recurse -Force -ErrorAction SilentlyContinue
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

**Escalate to reinstall when:** Docker Desktop binary itself is corrupted or installer state is broken.

```powershell
winget uninstall --id Docker.DockerDesktop
winget install --id Docker.DockerDesktop
```

---

## 5. Node.js / npm Issues

### node / npm Not Found

```powershell
# Locate any node binaries
where.exe node 2>$null
Get-ChildItem "C:\Program Files\nodejs" -ErrorAction SilentlyContinue

# Check nvm-windows
nvm list

# If nvm is installed but no active version
nvm install lts
nvm use lts

# Install Node via winget (no nvm)
winget install --id OpenJS.NodeJS.LTS
```

### nvm Conflicts (Multiple Node Versions)

```powershell
# nvm-windows stores versions here
Get-ChildItem "$env:APPDATA\nvm"

# Check active version symlink
Get-Item "$env:ProgramFiles\nodejs" | Select-Object Target

# Switch version
nvm use 20.x.x   # use exact version from `nvm list`

# If nvm symlink is broken
nvm use lts --force

# PATH should contain %NVM_HOME% and %NVM_SYMLINK% — verify:
[System.Environment]::GetEnvironmentVariable("NVM_HOME","Machine")
[System.Environment]::GetEnvironmentVariable("NVM_SYMLINK","Machine")
```

### npm Permission Errors

```powershell
# Fix npm global prefix to user-writable location
npm config set prefix "$env:APPDATA\npm"

# Ensure that location is on PATH
$npmPath = "$env:APPDATA\npm"
if ($env:PATH -notlike "*$npmPath*") {
    [System.Environment]::SetEnvironmentVariable(
        "PATH",
        [System.Environment]::GetEnvironmentVariable("PATH","User") + ";$npmPath",
        "User"
    )
}

# Fix corrupted npm cache
npm cache clean --force
```

### Global Packages Not Found After Install

```powershell
# Where are global packages installed?
npm root -g
npm bin -g

# Add npm bin to PATH permanently
$npmBin = npm bin -g
[System.Environment]::SetEnvironmentVariable(
    "PATH",
    [System.Environment]::GetEnvironmentVariable("PATH","User") + ";$npmBin",
    "User"
)
```

---

## 6. Python Issues

### python Not Found / Wrong Version

```powershell
# Find all Python installs
where.exe python
Get-ChildItem "C:\Python*","$env:LOCALAPPDATA\Programs\Python\*" -ErrorAction SilentlyContinue | Where-Object { Test-Path "$_\python.exe" }

# py launcher (preferred on Windows)
py --list
py -3.11 --version

# Install specific version via winget
winget install --id Python.Python.3.12

# Set default via py launcher (user-level)
# Create/edit %APPDATA%\Python\py.ini:
$pyIni = "$env:APPDATA\Python\py.ini"
if (-not (Test-Path $pyIni)) { New-Item -Path $pyIni -Force | Out-Null }
Set-Content $pyIni "[defaults]`npython=3.12"
```

### pip Not Found

```powershell
# Use module syntax
python -m pip --version

# Reinstall pip
python -m ensurepip --upgrade
python -m pip install --upgrade pip

# If pip command is missing from PATH
$scripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))"
[System.Environment]::SetEnvironmentVariable(
    "PATH",
    [System.Environment]::GetEnvironmentVariable("PATH","User") + ";$scripts",
    "User"
)
```

### venv Activation Issues

```powershell
# Create and activate
python -m venv .venv
.\.venv\Scripts\Activate.ps1   # PowerShell
# or
.\.venv\Scripts\activate.bat   # CMD

# If Activate.ps1 is blocked by execution policy
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Deactivate
deactivate
```

### Python PATH Conflicts (Multiple Pythons)

```powershell
# See all python.exe entries in PATH order
$env:PATH -split ";" | ForEach-Object {
    $p = Join-Path $_ "python.exe"
    if (Test-Path $p) { "$p" }
}

# Fix by reordering PATH — put desired Python first in User PATH
$desired = "C:\Python312"
$current = [System.Environment]::GetEnvironmentVariable("PATH","User")
$cleaned = ($current -split ";" | Where-Object { $_ -notlike "*Python*" }) -join ";"
[System.Environment]::SetEnvironmentVariable("PATH","$desired;$desired\Scripts;$cleaned","User")
```

---

## 7. .NET SDK Issues

### dotnet Not Found

```powershell
# Check install locations
Get-ChildItem "C:\Program Files\dotnet\sdk" -ErrorAction SilentlyContinue

# Add to PATH
$env:PATH += ";C:\Program Files\dotnet"
[System.Environment]::SetEnvironmentVariable(
    "PATH",
    [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";C:\Program Files\dotnet",
    "Machine"
)

# Reinstall
winget install --id Microsoft.DotNet.SDK.8
```

### Version Conflicts / global.json Pinning

```powershell
# See all installed SDKs
dotnet --list-sdks

# See all installed runtimes
dotnet --list-runtimes

# Check which SDK is active in current dir (respects global.json)
dotnet --version

# Install a specific SDK version
winget install --id Microsoft.DotNet.SDK.7

# Override global.json for a project
# Edit global.json: { "sdk": { "version": "8.0.0", "rollForward": "latestMinor" } }
```

### NuGet Restore Failures

```powershell
# Clear NuGet caches
dotnet nuget locals all --clear

# Check configured sources
dotnet nuget list source

# Add nuget.org if missing
dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org

# Corporate feed: add credentials
dotnet nuget add source https://pkgs.dev.azure.com/<org>/_packaging/<feed>/nuget/v3/index.json `
    -n <FeedName> -u <user> -p <PAT> --store-password-in-clear-text
```

### Build Errors After SDK Update

```powershell
# Identify which SDK is selected
dotnet --version

# Force rollback via global.json
Set-Content global.json '{ "sdk": { "version": "7.0.0", "rollForward": "latestMinor" } }'

# Repair workloads
dotnet workload repair
```

---

## 8. WSL Issues

### WSL Not Installed

```powershell
# Windows 11 — single command install
wsl --install

# Install specific distro
wsl --install -d Ubuntu-22.04

# List available distros
wsl --list --online
```

### WSL Not Working / Kernel Issues

```powershell
# Check status
wsl --status
wsl --version

# Update kernel
wsl --update

# Force shutdown and restart
wsl --shutdown
wsl

# If WSL virtual machine won't start, enable required Windows features
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
# Then reboot
```

### Ubuntu Distro Problems

```bash
# Inside WSL — update packages
sudo apt update && sudo apt upgrade -y

# Fix broken packages
sudo apt --fix-broken install

# Reset a distro (destructive — removes all data)
# In PowerShell:
wsl --unregister Ubuntu-22.04
wsl --install -d Ubuntu-22.04
```

### File Permission Issues (Windows ↔ WSL)

```bash
# Inside WSL — fix /etc/wsl.conf to control mount options
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[automount]
options = "metadata,umask=22,fmask=11"

[interop]
appendWindowsPath = false
EOF
# Restart WSL: wsl --shutdown
```

### WSL Networking Issues

```powershell
# Reset WSL networking
wsl --shutdown
netsh winsock reset
netsh int ip reset
# Reboot recommended

# DNS fix inside WSL
# /etc/wsl.conf:
# [network]
# generateResolvConf = false
# Then manually set /etc/resolv.conf:
# nameserver 8.8.8.8
```

---

## 8.5. Kubernetes Tooling Issues

### kubectl Context Problems

```powershell
# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# View current context
kubectl config current-context

# If kubeconfig is missing or corrupted
$kubeconfigPath = "$env:USERPROFILE\.kube\config"
Test-Path $kubeconfigPath

# AKS: re-fetch credentials
az aks get-credentials --resource-group <rg> --name <cluster> --overwrite-existing
```

### helm Repo Issues

```powershell
# List configured repos
helm repo list

# Update all repos
helm repo update

# Add common repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Fix corrupted cache
Remove-Item "$env:APPDATA\helm\cache" -Recurse -Force -ErrorAction SilentlyContinue
helm repo update
```

### Kubernetes DNS / Networking Debugging

```powershell
# Test connectivity from within a cluster
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Check pod status
kubectl get pods --all-namespaces | Select-String -Pattern "Error|CrashLoop|ImagePull"

# View pod logs
kubectl logs <pod-name> --tail=50
kubectl logs <pod-name> --previous   # logs from crashed container
```

---

## 9. VS Code Issues

### Extensions Not Loading

```powershell
# Launch with verbose logging
code --verbose

# List installed extensions
code --list-extensions

# Reinstall a broken extension
code --uninstall-extension <publisher.extension>
code --install-extension <publisher.extension>

# Clear extension cache (close VS Code first)
Remove-Item "$env:USERPROFILE\.vscode\extensions\*\.obsolete" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Code\Cache" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Code\CachedExtensions" -Recurse -Force -ErrorAction SilentlyContinue
```

### IntelliSense Broken

```powershell
# TypeScript/JS: clear TS server cache
Remove-Item "$env:APPDATA\Code\User\workspaceStorage" -Recurse -Force

# C#: reload OmniSharp / Roslyn
# In VS Code: Ctrl+Shift+P → ".NET: Restart Language Server"

# Python: select correct interpreter
# Ctrl+Shift+P → "Python: Select Interpreter" → choose the right .venv or system python

# General: reload window
# Ctrl+Shift+P → "Developer: Reload Window"
```

### Extension Storage Path Issues

```powershell
# Default extensions path
"$env:USERPROFILE\.vscode\extensions"

# Override extensions path (e.g., moved to D:\)
# Set in VS Code settings.json or launch with:
code --extensions-dir "D:\vscode-extensions"

# Or set permanently in settings.json:
# "$env:APPDATA\Code\User\settings.json"
# Add: "vscode.extensionsGallery": { ... }
```

---

## 10. PowerShell Issues

### Execution Policy Blocking Scripts

```powershell
# Check current policies
Get-ExecutionPolicy -List

# Allow local scripts for current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Unblock a specific downloaded script
Unblock-File -Path .\script.ps1
```

### Profile Not Loading

```powershell
# Check profile paths
$PROFILE | Select-Object *

# Create profile if missing
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -Type File -Force
}

# Test profile manually
. $PROFILE

# Debug profile errors
pwsh -NoProfile   # start without profile to isolate issues
pwsh -Command ". '$PROFILE'; Write-Host 'Profile OK'"
```

### Module Not Found

```powershell
# Check PSModulePath
$env:PSModulePath -split ";"

# Find where a module is installed
Get-Module -ListAvailable <ModuleName>

# Install missing module
Install-Module -Name <ModuleName> -Scope CurrentUser -Force

# Fix PSGallery if untrusted
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

### PowerShell 5 vs 7 Confusion

```powershell
# Check which you're running
$PSVersionTable.PSVersion

# Install pwsh (PowerShell 7)
winget install --id Microsoft.PowerShell

# Set pwsh as default terminal in Windows Terminal:
# Settings → Default profile → PowerShell (not Windows PowerShell)
```

---

## 11. Azure CLI Issues

### az Login Problems

```powershell
# Clear cached tokens
az account clear
Remove-Item "$env:USERPROFILE\.azure" -Recurse -Force -ErrorAction SilentlyContinue

# Login interactively
az login

# Login with device code (headless / WSL)
az login --use-device-code

# Service principal login
az login --service-principal -u <appId> -p <password> --tenant <tenantId>
```

### Subscription Not Found / Wrong Subscription

```powershell
# List all subscriptions
az account list --output table

# Set active subscription
az account set --subscription "<subscription-name-or-id>"

# Verify
az account show
```

### Extension Issues

```powershell
# List installed extensions
az extension list --output table

# Update all extensions
az extension update --all

# Remove and reinstall a broken extension
az extension remove --name <extension>
az extension add --name <extension>

# Update az CLI itself
winget upgrade --id Microsoft.AzureCLI
```

---

## 11.5. GitHub CLI (gh) Issues

### gh Not Found

```powershell
# Check installation
Get-Command gh -ErrorAction SilentlyContinue
winget list --id GitHub.cli

# Install
winget install --id GitHub.cli

# Add to PATH if needed
$ghPath = "C:\Program Files\GitHub CLI"
if (Test-Path $ghPath) {
    $env:PATH += ";$ghPath"
}
```

### gh Auth Problems

```powershell
# Check auth status
gh auth status

# Re-authenticate (interactive)
gh auth login

# Login with token
$env:GH_TOKEN = "ghp_xxxxx"
gh auth status

# Switch between accounts
gh auth switch

# Clear all auth tokens
gh auth logout
```

### gh Extension Issues

```powershell
# List installed extensions
gh extension list

# Upgrade all extensions
gh extension upgrade --all

# Remove and reinstall a broken extension
gh extension remove <extension>
gh extension install <owner>/<extension>
```

### gh API Rate Limiting

```powershell
# Check rate limit status
gh api rate_limit

# If rate limited, ensure you're authenticated (authenticated gets 5000 req/hr vs 60):
gh auth status
```

---

## 12. PATH Corruption / Issues

### Diagnosing PATH Problems

```powershell
# Show current effective PATH (one entry per line)
$env:PATH -split ";" | Where-Object { $_ } | Sort-Object -Unique

# Show Machine-level PATH
[System.Environment]::GetEnvironmentVariable("PATH","Machine") -split ";"

# Show User-level PATH
[System.Environment]::GetEnvironmentVariable("PATH","User") -split ";"

# Find duplicate entries
$entries = $env:PATH -split ";"
$dupes = $entries | Group-Object | Where-Object { $_.Count -gt 1 }
$dupes | ForEach-Object { "DUPE: $($_.Name)" }

# Find non-existent PATH entries
$env:PATH -split ";" | Where-Object { $_ -and -not (Test-Path $_) } | ForEach-Object { "MISSING: $_" }
```

### Fixing PATH

```powershell
# Remove a specific entry from User PATH
$old = [System.Environment]::GetEnvironmentVariable("PATH","User")
$new = ($old -split ";" | Where-Object { $_ -ne "C:\path\to\remove" }) -join ";"
[System.Environment]::SetEnvironmentVariable("PATH",$new,"User")

# Add a missing entry to User PATH
$current = [System.Environment]::GetEnvironmentVariable("PATH","User")
[System.Environment]::SetEnvironmentVariable("PATH","$current;C:\new\path","User")

# Deduplicate PATH (preserves order, removes later dupes)
$clean = [System.Collections.Generic.LinkedHashSet[string]]::new()
$env:PATH -split ";" | Where-Object { $_ } | ForEach-Object { $clean.Add($_) | Out-Null }
$env:PATH = $clean -join ";"

# Reload PATH in current session without restarting
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")
```

**Warning:** Never remove System32 or PowerShell paths from Machine-level PATH.

---

## 13. Certificate / SSL Issues

### Corporate Proxy / MITM Certificate Errors

```powershell
# Test if corporate cert is the issue
curl.exe https://github.com -v 2>&1 | Select-String "issuer|subject|SSL"

# Export the corporate root CA from Windows cert store
$cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*<CorpCA>*" }
Export-Certificate -Cert $cert -FilePath "$env:TEMP\corp-ca.crt" -Type CERT

# Trust it in Git
git config --global http.sslCAInfo "$env:TEMP\corp-ca.crt"

# Trust it in Node.js (add to env permanently)
[System.Environment]::SetEnvironmentVariable("NODE_EXTRA_CA_CERTS","$env:TEMP\corp-ca.crt","User")

# Trust it in Python requests / pip
$certFile = python -c "import certifi; print(certifi.where())"
# Append the corporate cert to that file manually or:
pip config set global.cert "$env:TEMP\corp-ca.crt"

# Trust it in .NET
# Import into Windows cert store (already done by IT) usually suffices;
# if not, set: DOTNET_SSL_CERT_FILE env var

# Trust it for Azure CLI
az config set core.cafile="$env:TEMP\corp-ca.crt"
```

### mkcert Setup (Local Development HTTPS)

```powershell
# Install mkcert
winget install --id FiloSottile.mkcert

# Install local CA
mkcert -install

# Generate cert for local dev
mkcert localhost 127.0.0.1 ::1
# Creates localhost.pem and localhost-key.pem

# Verify trust
mkcert -CAROOT
```

### Self-Signed Cert Errors

```powershell
# Docker pulls failing with cert errors
# Add registry cert to Docker daemon config (Docker Desktop → Settings → Docker Engine):
# "insecure-registries": ["myregistry.local:5000"]

# kubectl / helm cert errors — configure kubeconfig to trust CA:
kubectl config set-cluster <cluster> --certificate-authority=ca.crt
```

---

## 14. Comprehensive Health Check Script

Save as `Check-DevEnv.ps1` and run in an elevated PowerShell session:

```powershell
<#
.SYNOPSIS
    Full health check for devbox_bootstrap Windows developer environment.
#>
param([switch]$Fix)

$pass = 0; $fail = 0; $warn = 0

function Test-Tool {
    param($Name, [scriptblock]$Check, [scriptblock]$FixCmd = $null, [string]$Hint = "")
    try {
        $result = & $Check 2>&1
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw $result }
        Write-Host "  [PASS] $Name : $result" -ForegroundColor Green
        $script:pass++
    } catch {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Hint) { Write-Host "         Hint: $Hint" -ForegroundColor Yellow }
        if ($Fix -and $FixCmd) { Write-Host "         Attempting fix..." -ForegroundColor Cyan; & $FixCmd }
        $script:fail++
    }
}

function Test-Warn {
    param($Name, [scriptblock]$Check, [string]$Hint = "")
    try {
        $result = & $Check 2>&1
        Write-Host "  [PASS] $Name : $result" -ForegroundColor Green
        $script:pass++
    } catch {
        Write-Host "  [WARN] $Name - $Hint" -ForegroundColor Yellow
        $script:warn++
    }
}

Write-Host "`n====== Dev Environment Health Check ======`n" -ForegroundColor Cyan

Write-Host "--- Core Tools ---" -ForegroundColor White
Test-Tool "winget"   { (winget --version) }
Test-Tool "git"      { git --version } -Hint "Run: winget install Git.Git"
Test-Tool "node"     { node --version } -Hint "Run: winget install OpenJS.NodeJS.LTS"
Test-Tool "npm"      { npm --version }
Test-Tool "python"   { python --version } -Hint "Run: winget install Python.Python.3.12"
Test-Tool "pip"      { python -m pip --version }
Test-Tool "dotnet"   { dotnet --version } -Hint "Run: winget install Microsoft.DotNet.SDK.8"
Test-Tool "az"       { az --version 2>&1 | Select-Object -First 1 } -Hint "Run: winget install Microsoft.AzureCLI"
Test-Tool "code"     { code --version 2>&1 | Select-Object -First 1 }
Test-Tool "gh"       { gh --version } -Hint "Run: winget install GitHub.cli"
Test-Tool "pwsh"     { pwsh --version }

Write-Host "`n--- Container & K8s Tools ---" -ForegroundColor White
Test-Tool "docker"   { docker --version } -Hint "Start Docker Desktop"
Test-Warn "docker-daemon" { docker info 2>&1 | Select-String "Server Version" } -Hint "Docker Desktop not running"
Test-Tool "kubectl"  { kubectl version --client --short 2>&1 } -Hint "Run: winget install Kubernetes.kubectl"
Test-Warn "helm"     { helm version --short 2>&1 } -Hint "Run: winget install Helm.Helm"

Write-Host "`n--- WSL ---" -ForegroundColor White
Test-Warn "wsl"      { wsl --version 2>&1 | Select-Object -First 1 } -Hint "Run: wsl --install"
Test-Warn "wsl-distro" { wsl -e true 2>&1 } -Hint "No default WSL distro; run: wsl --install -d Ubuntu-22.04"

Write-Host "`n--- SSH ---" -ForegroundColor White
Test-Warn "ssh-agent" { Get-Service ssh-agent | Where-Object Status -eq Running } -Hint "Run: Start-Service ssh-agent"
Test-Warn "ssh-key"   { Get-ChildItem "$env:USERPROFILE\.ssh\*.pub" } -Hint "Run: ssh-keygen -t ed25519"

Write-Host "`n--- PATH Sanity ---" -ForegroundColor White
$dupes = ($env:PATH -split ";" | Group-Object | Where-Object { $_.Count -gt 1 }).Count
if ($dupes -gt 0) {
    Write-Host "  [WARN] $dupes duplicate PATH entries found" -ForegroundColor Yellow
    $script:warn++
} else {
    Write-Host "  [PASS] No duplicate PATH entries" -ForegroundColor Green
    $script:pass++
}
$missing = ($env:PATH -split ";" | Where-Object { $_ -and -not (Test-Path $_) }).Count
if ($missing -gt 0) {
    Write-Host "  [WARN] $missing PATH entries point to non-existent directories" -ForegroundColor Yellow
    $script:warn++
} else {
    Write-Host "  [PASS] All PATH directories exist" -ForegroundColor Green
    $script:pass++
}

Write-Host "`n--- Connectivity ---" -ForegroundColor White
Test-Warn "github-https" { Invoke-WebRequest https://github.com -UseBasicParsing -TimeoutSec 5 | Select-Object -Expand StatusCode } -Hint "Check proxy/firewall/SSL cert"
Test-Warn "nuget-feed"   { Invoke-WebRequest https://api.nuget.org/v3/index.json -UseBasicParsing -TimeoutSec 5 | Select-Object -Expand StatusCode } -Hint "NuGet unreachable"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Results: " -NoNewline
Write-Host "$pass passed  " -ForegroundColor Green -NoNewline
Write-Host "$warn warnings  " -ForegroundColor Yellow -NoNewline
Write-Host "$fail failed" -ForegroundColor Red
if ($fail -gt 0) { Write-Host "Run with -Fix flag to attempt automatic repairs: .\Check-DevEnv.ps1 -Fix" -ForegroundColor Cyan }
```

---

## Escalation Guide

| Symptom | Try First | Escalate To |
|---|---|---|
| Tool missing from PATH | Add PATH entry | Reinstall via winget |
| winget broken | Reset sources, clear cache | Reinstall App Installer from Store |
| Docker Desktop crashes | Restart, reset WSL | Full uninstall + reinstall |
| WSL corrupted | `wsl --unregister` + reinstall distro | `wsl --uninstall` + re-enable Windows feature |
| Python env chaos | Fix PATH order, recreate venv | Uninstall all Pythons, reinstall one version |
| .NET build broken | Clear NuGet cache, repair workloads | Uninstall all SDKs, reinstall target version |
| Git creds broken | Clear credential manager | Reinstall Git Credential Manager |
| VS Code broken | Clear cache, reinstall extensions | Full VS Code uninstall + reinstall |
| PowerShell profile broken | Test with `-NoProfile`, fix profile | Delete profile, recreate from scratch |
| SSL/cert errors everywhere | Add corp CA to all tool stores | Involve IT — may need new cert bundle |
| gh CLI auth broken | `gh auth logout` + `gh auth login` | Reinstall: `winget uninstall GitHub.cli && winget install GitHub.cli` |
| kubectl can't connect | Re-fetch AKS credentials | Check VPN, firewall, cluster status |

---

## References

- devbox_bootstrap: [`readme.md`](../../readme.md)
- winget packages: `winget search <tool>`
- WSL docs: https://learn.microsoft.com/en-us/windows/wsl/
- Docker troubleshooting: https://docs.docker.com/desktop/troubleshoot/
- .NET SDK: https://dotnet.microsoft.com/download
