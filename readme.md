# Devbox Configuration

This script automates the setup of a complete Windows development environment with Azure, .NET, Python, Node.js, and various development tools.

## Prerequisites

- Windows 11 with administrator privileges
- Internet connection
- Windows Package Manager (winget) - comes pre-installed on Windows 11

## Installation

Run the commands below in an **elevated PowerShell or Command Prompt** (Run as Administrator).

---

## Windows Features

```bash
# Enable Hyper-V & Windows Sandbox
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V
DISM /Online /Enable-Feature /FeatureName:Containers-DisposableClientVM /All
```

---

## Version Control & Git

```bash
winget install Git.Git --accept-package-agreements --accept-source-agreements --silent

# GitHub CLI (gh) - manage repos, PRs, issues from the terminal
winget install GitHub.cli --accept-package-agreements --accept-source-agreements --silent
# Delta (better git diffs with syntax highlighting)
winget install dandavison.delta --accept-package-agreements --accept-source-agreements --silent

# Optional: GUI Git Clients
# winget install GitHub.GitHubDesktop --accept-package-agreements --accept-source-agreements --silent
# winget install Axosoft.GitKraken --accept-package-agreements --accept-source-agreements --silent
```

### Git Configuration (run after Git is installed)

```bash
# Configure your Git identity
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Useful Git aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.unstage "reset HEAD --"
git config --global alias.last "log -1 HEAD"

# If using delta, configure Git to use it as the pager
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global merge.conflictstyle diff3
```

---

## GitHub Copilot CLI

AI-powered command line assistant. Requires an active [GitHub Copilot subscription](https://github.com/features/copilot/plans) and PowerShell v6+.

For full setup details, see the [official installation guide](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli).

```bash
# GitHub Copilot CLI (stable)
winget install GitHub.Copilot --accept-package-agreements --accept-source-agreements --silent

# GitHub Copilot CLI (prerelease)
winget install GitHub.Copilot.Prerelease --accept-package-agreements --accept-source-agreements --silent
```

---

## Container & Virtualization

```bash
winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent

# Alternative: Podman Desktop
# winget install RedHat.Podman-Desktop --accept-package-agreements --accept-source-agreements --silent

# Rancher Desktop (Kubernetes + Container Management)
# winget install suse.RancherDesktop --accept-package-agreements --accept-source-agreements --silent
```

---

## Azure Tools

```bash
winget install Microsoft.Azure.AZCopy.10 --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.Azure.CosmosEmulator --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.Azure.StorageExplorer --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.AzureCLI --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.Azd --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.Bicep --accept-package-agreements --accept-source-agreements --silent
# Azure Data Studio (SQL Server, PostgreSQL, MySQL management)
winget install Microsoft.AzureDataStudio --accept-package-agreements --accept-source-agreements --silent
```

### Azure CLI Extensions

```bash
az login
az extension add -n azure-devops
az extension add -n ml
```

---

## Cloud & Infrastructure as Code

```bash
# Terraform
winget install Hashicorp.Terraform --accept-package-agreements --accept-source-agreements --silent
# Pulumi (alternative to Terraform)
# winget install Pulumi.Pulumi --accept-package-agreements --accept-source-agreements --silent
```

---

## Kubernetes Tools

```bash
# Kubectl
winget install Kubernetes.kubectl --accept-package-agreements --accept-source-agreements --silent
# Helm (Kubernetes package manager)
winget install Helm.Helm --accept-package-agreements --accept-source-agreements --silent
# k9s (Kubernetes CLI UI)
winget install Derailed.k9s --accept-package-agreements --accept-source-agreements --silent
# Lens (Kubernetes IDE)
# winget install Mirantis.Lens --accept-package-agreements --accept-source-agreements --silent
```

---

## .NET Development

```bash
# .NET SDKs
winget install Microsoft.DotNet.SDK.8 --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.DotNet.SDK.9 --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.DotNet.SDK.Preview --accept-package-agreements --accept-source-agreements --silent
# Visual Studio 2022
winget install Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.VisualStudio.2022.Enterprise --accept-package-agreements --accept-source-agreements --silent
```

---

## Python Development

```bash
# Python 3.12 (recommended - latest stable)
winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements --silent
# Python 3.9 (if needed for legacy projects)
# winget install Python.Python.3.9 --accept-package-agreements --accept-source-agreements --silent
# Upgrade pip
python -m pip install --upgrade pip
# Install Python development tools
pip install poetry
pip install black
pip install pylint
pip install pytest
```

---

## Node.js & JavaScript Development

```bash
winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent
winget install Yarn.Yarn --accept-package-agreements --accept-source-agreements --silent
```

### Node.js Global Packages

```bash
npm install -g typescript
npm install -g ts-node
npm install -g eslint
npm install -g prettier
npm install -g pnpm
npm install -g hardhat
npm install -g httpyac
npm install -g commitizen

# Framework CLIs (uncomment as needed)
# npm install -g @angular/cli
# npm install -g create-react-app
# npm install -g create-next-app
# npm install -g @vue/cli
```

---

## Go Development

```bash
# Go programming language
winget install GoLang.Go --accept-package-agreements --accept-source-agreements --silent
```

---

## Rust Development

```bash
# Rust toolchain (rustup, cargo, rustc)
winget install Rustlang.Rustup --accept-package-agreements --accept-source-agreements --silent
```

---

## Java Development

```bash
# Microsoft OpenJDK 21 (LTS)
# winget install Microsoft.OpenJDK.21 --accept-package-agreements --accept-source-agreements --silent
# Maven (build tool)
# winget install Apache.Maven --accept-package-agreements --accept-source-agreements --silent
# Gradle (build tool)
# winget install Gradle.Gradle --accept-package-agreements --accept-source-agreements --silent
```

---

## PowerShell & Terminal

```bash
winget install Microsoft.PowerShell --accept-package-agreements --accept-source-agreements --silent
# Windows Terminal (usually pre-installed on Windows 11)
winget install Microsoft.WindowsTerminal --accept-package-agreements --accept-source-agreements --silent
# Oh My Posh (PowerShell theme engine)
winget install JanDeDobbeleer.OhMyPosh --accept-package-agreements --accept-source-agreements --silent
```

---

## Visual Studio Code & Extensions

```bash
winget install Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent
```

### Essential Extensions

```bash
# General Development
code --install-extension editorconfig.editorconfig
code --install-extension eamodio.gitlens
code --install-extension usernamehw.errorlens
code --install-extension aaron-bond.better-comments
code --install-extension esbenp.prettier-vscode
# AI Assistants
code --install-extension github.copilot
code --install-extension github.copilot-chat
code --install-extension saoudrizwan.claude-dev
# Markdown
code --install-extension davidanson.vscode-markdownlint
code --install-extension yzhang.markdown-all-in-one
# Data & CSV
code --install-extension mechatroner.rainbow-csv
# Languages
code --install-extension golang.go
# Azure Extensions
code --install-extension ms-azure-devops.azure-pipelines
code --install-extension ms-azuretools.azure-dev
code --install-extension ms-azuretools.vscode-azure-github-copilot
code --install-extension ms-azuretools.vscode-azure-mcp-server
code --install-extension ms-azuretools.vscode-azureappservice
code --install-extension ms-azuretools.vscode-azurecontainerapps
code --install-extension ms-azuretools.vscode-azurefunctions
code --install-extension ms-azuretools.vscode-azureresourcegroups
code --install-extension ms-azuretools.vscode-azurestaticwebapps
code --install-extension ms-azuretools.vscode-azurestorage
code --install-extension ms-azuretools.vscode-azurevirtualmachines
code --install-extension ms-azuretools.vscode-bicep
code --install-extension ms-azuretools.vscode-cosmosdb
# Container & Docker
code --install-extension ms-azuretools.vscode-containers
code --install-extension ms-azuretools.vscode-docker
# .NET Extensions
code --install-extension ms-dotnettools.csdevkit
code --install-extension ms-dotnettools.csharp
code --install-extension ms-dotnettools.dotnet-interactive-vscode
code --install-extension ms-dotnettools.vscode-dotnet-runtime
code --install-extension ms-dotnettools.vscodeintellicode-csharp
code --install-extension ms-vscode.csharp
# Python Extensions
code --install-extension ms-python.debugpy
code --install-extension ms-python.flake8
code --install-extension ms-python.isort
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-python.vscode-python-envs
# Jupyter Notebooks
code --install-extension ms-toolsai.jupyter
# API Development
code --install-extension humao.rest-client
code --install-extension rangav.vscode-thunder-client
# Database
code --install-extension cweijan.vscode-database-client2
# Other Utilities
code --install-extension ms-vscode.azurecli
code --install-extension ms-vscode.notepadplusplus-keybindings
code --install-extension ms-vscode.powershell
code --install-extension ritwickdey.liveserver
```

---

## CLI Utilities

```bash
# jq (JSON processor)
winget install jqlang.jq --accept-package-agreements --accept-source-agreements --silent
# yq (YAML/XML/TOML processor)
winget install MikeFarah.yq --accept-package-agreements --accept-source-agreements --silent
# ripgrep (fast recursive search)
winget install BurntSushi.ripgrep.MSVC --accept-package-agreements --accept-source-agreements --silent
# fzf (fuzzy finder)
winget install junegunn.fzf --accept-package-agreements --accept-source-agreements --silent
# bat (cat with syntax highlighting)
winget install sharkdp.bat --accept-package-agreements --accept-source-agreements --silent
# fd (fast find alternative)
winget install sharkdp.fd --accept-package-agreements --accept-source-agreements --silent
# wget
winget install JernejSimoncic.Wget --accept-package-agreements --accept-source-agreements --silent
```

---

## API Development & Testing

```bash
# Bruno (open-source API client)
winget install Bruno.Bruno --accept-package-agreements --accept-source-agreements --silent
# Postman
winget install Postman.Postman --accept-package-agreements --accept-source-agreements --silent
# Insomnia
# winget install Insomnia.Insomnia --accept-package-agreements --accept-source-agreements --silent
```

---

## Database Tools

```bash
# DBeaver (universal database tool)
winget install dbeaver.dbeaver --accept-package-agreements --accept-source-agreements --silent
# MongoDB Compass
# winget install MongoDB.Compass.Full --accept-package-agreements --accept-source-agreements --silent
# Redis Insight
# winget install Redis.RedisInsight --accept-package-agreements --accept-source-agreements --silent
```

---

## Security & Debugging

```bash
# KeePass (password manager)
winget install DominikReichl.KeePass --accept-package-agreements --accept-source-agreements --silent
# Windows Debugger
winget install Microsoft.WinDbg --accept-package-agreements --accept-source-agreements --silent
# Fiddler (web debugging proxy)
winget install Telerik.Fiddler.Everywhere --accept-package-agreements --accept-source-agreements --silent
# Wireshark (network protocol analyzer)
winget install WiresharkFoundation.Wireshark --accept-package-agreements --accept-source-agreements --silent
# Sysinternals Suite (Process Explorer, Process Monitor, Autoruns, etc.)
winget install Microsoft.Sysinternals.Suite --accept-package-agreements --accept-source-agreements --silent
# OWASP ZAP (security testing)
# winget install ZAP.ZAP --accept-package-agreements --accept-source-agreements --silent
# Trivy (container security scanner)
# winget install aquasecurity.trivy --accept-package-agreements --accept-source-agreements --silent
```

---

## Text Editors & Productivity

```bash
# Notepad++
winget install Notepad++.Notepad++ --accept-package-agreements --accept-source-agreements --silent
# Sublime Text 4
winget install SublimeHQ.SublimeText.4 --accept-package-agreements --accept-source-agreements --silent
# Windows Notepad (from MS Store)
winget install 9MSMLRH6LZF3 --accept-package-agreements --accept-source-agreements --silent
# PowerToys (Windows utilities)
winget install Microsoft.PowerToys --accept-package-agreements --accept-source-agreements --silent
# 7-Zip (file compression)
winget install 7zip.7zip --accept-package-agreements --accept-source-agreements --silent
# WinDirStat (disk usage analyzer)
winget install WinDirStat.WinDirStat --accept-package-agreements --accept-source-agreements --silent
# Everything (fast file search)
winget install voidtools.Everything --accept-package-agreements --accept-source-agreements --silent
# ShareX (screenshot tool)
winget install ShareX.ShareX --accept-package-agreements --accept-source-agreements --silent
# Ditto (clipboard manager)
winget install Ditto.Ditto --accept-package-agreements --accept-source-agreements --silent
# WinMerge (file/folder diff and merge)
winget install WinMerge.WinMerge --accept-package-agreements --accept-source-agreements --silent
# Obsidian (knowledge base / notes)
# winget install Obsidian.Obsidian --accept-package-agreements --accept-source-agreements --silent
# draw.io Desktop (diagramming)
# winget install JGraph.Draw --accept-package-agreements --accept-source-agreements --silent
```

---

## Browsers

```bash
# Google Chrome
winget install Google.Chrome --accept-package-agreements --accept-source-agreements --silent
# Firefox
# winget install Mozilla.Firefox --accept-package-agreements --accept-source-agreements --silent
# Firefox Developer Edition
# winget install Mozilla.Firefox.DeveloperEdition --accept-package-agreements --accept-source-agreements --silent
```

---

## Network & Tunneling

```bash
# ngrok (expose local servers to the internet)
winget install Ngrok.Ngrok --accept-package-agreements --accept-source-agreements --silent
# WireGuard (VPN)
# winget install WireGuard.WireGuard --accept-package-agreements --accept-source-agreements --silent
```

---

## WSL & Linux Development

```bash
winget install Microsoft.WSL --accept-package-agreements --accept-source-agreements --silent

wsl --update
wsl --install -d Ubuntu-24.04
```

### WSL Setup & Configuration

```bash
# Install Miniconda in WSL
wsl -d Ubuntu-24.04 -e bash -c "wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && bash ~/miniconda.sh -b -p ~/miniconda && echo 'export PATH=\"~/miniconda/bin:\$PATH\"' >> ~/.bashrc && ~/miniconda/bin/conda init bash"
# Update Ubuntu packages
wsl -d Ubuntu-24.04 -e bash -c "sudo apt update && sudo apt upgrade -y"
# Optional: Install useful Linux tools
wsl -d Ubuntu-24.04 -e bash -c "sudo apt install -y zsh tmux neovim fzf ripgrep bat exa git-lfs build-essential"
# Optional: Install Oh My Zsh
# wsl -d Ubuntu-24.04 -e bash -c "sh -c '$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)'"
```

---

## SSL/TLS Development Certificates

```bash
# mkcert (locally-trusted development certificates)
winget install FiloSottile.mkcert --accept-package-agreements --accept-source-agreements --silent
# Setup local CA
mkcert -install
```

---

## Communication & Collaboration

```bash
# Discord
winget install Discord.Discord --accept-package-agreements --accept-source-agreements --silent
# Signal
winget install OpenWhisperSystems.Signal --accept-package-agreements --accept-source-agreements --silent
# Microsoft Teams
# winget install Microsoft.Teams --accept-package-agreements --accept-source-agreements --silent
# Slack
# winget install SlackTechnologies.Slack --accept-package-agreements --accept-source-agreements --silent
# Zoom
winget install Zoom.Zoom --accept-package-agreements --accept-source-agreements --silent
```

---

## Media & Utilities

```bash
# VLC Media Player
winget install VideoLAN.VLC --accept-package-agreements --accept-source-agreements --silent
# FFmpeg (video/audio processing)
winget install Gyan.FFmpeg --accept-package-agreements --accept-source-agreements --silent
```

---

## Final Steps

```bash
# Upgrade all installed packages
winget upgrade --all
# Restart your computer to complete installation
shutdown /r /t 60 /c "Restarting to complete devbox setup. Save your work!"
```

---

## Post-Installation Checklist

- [ ] Configure Git with your name and email
- [ ] Sign in to Azure CLI (`az login`)
- [ ] Sign in to Docker Desktop
- [ ] Configure VS Code settings and keybindings
- [ ] Set up PowerShell profile customizations
- [ ] Configure Windows Terminal themes
- [ ] Install additional VS Code extensions as needed
- [ ] Set up WSL development environment
- [ ] Configure mkcert for local HTTPS development
- [ ] Test Docker and Kubernetes functionality
- [ ] Set up database connections in Azure Data Studio/DBeaver

---

## Customization

Edit this file to:

- Comment out tools you don't need
- Add project-specific tools
- Adjust Python/Node.js/Go versions
- Add additional VS Code extensions
- Configure additional package managers (chocolatey, scoop)

---

## Troubleshooting

### If winget is not found

```powershell
# Install from Microsoft Store
start ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1
```

### If installations fail

- Run PowerShell/CMD as Administrator
- Check your internet connection
- Update winget: `winget upgrade winget`
- Check Windows Update for pending updates

### Reset PATH if commands aren't found

```powershell
# Close and reopen your terminal after installations
# Or refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

---

## Additional Resources

- [Winget Documentation](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/)
- [VS Code Documentation](https://code.visualstudio.com/docs)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
