# Devbox Configuration

```bash
# Enable Hyper-V & Windows Sandbox
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V
DISM /Online /Enable-Feature /FeatureName:Containers-DisposableClientVM /All


winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent

# KeePass
winget install DominikReichl.KeePass --accept-package-agreements --accept-source-agreements --silent


winget install Git.Git --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.Azure.AZCopy.10 --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.Azure.CosmosEmulator --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.Azure.StorageExplorer --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.AzureCLI --accept-package-agreements --accept-source-agreements --silent
    az login
    az extension add -n azure-devops
    az extension add -n ml

winget install Microsoft.Azd --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.Bicep --accept-package-agreements --accept-source-agreements --silent

# winget install Microsoft.DotNet.SDK.6 --accept-package-agreements --accept-source-agreements --silent
# winget install Microsoft.DotNet.SDK.7 --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.DotNet.SDK.8 --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.DotNet.SDK.9 --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.DotNet.SDK.Preview --accept-package-agreements --accept-source-agreements --silent

winget install Git.Git  --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.PowerShell --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.PowerToys --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --silent
winget install Microsoft.VisualStudio.2022.Enterprise --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent
    code --install-extension davidanson.vscode-markdownlint
    code --install-extension editorconfig.editorconfig
    code --install-extension github.copilot
    code --install-extension github.copilot-chat
    code --install-extension saoudrizwan.claude-dev
    code --install-extension golang.go
    code --install-extension mechatroner.rainbow-csv
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
    code --install-extension ms-azuretools.vscode-containers
    code --install-extension ms-azuretools.vscode-cosmosdb
    code --install-extension ms-azuretools.vscode-docker
    code --install-extension ms-dotnettools.csdevkit
    code --install-extension ms-dotnettools.csharp
    code --install-extension ms-dotnettools.dotnet-interactive-vscode
    code --install-extension ms-dotnettools.vscode-dotnet-runtime
    code --install-extension ms-dotnettools.vscodeintellicode-csharp
    code --install-extension ms-python.debugpy
    code --install-extension ms-python.flake8
    code --install-extension ms-python.isort
    code --install-extension ms-python.python
    code --install-extension ms-python.vscode-pylance
    code --install-extension ms-python.vscode-python-envs
    code --install-extension ms-toolsai.jupyter
    code --install-extension ms-vscode.azurecli
    code --install-extension ms-vscode.csharp
    code --install-extension ms-vscode.notepadplusplus-keybindings
    code --install-extension ms-vscode.powershell

winget install Microsoft.WinDbg --accept-package-agreements --accept-source-agreements --silent

winget install Microsoft.WSL --accept-package-agreements --accept-source-agreements --silent
    wsl --update
    wsl --install -d Ubuntu-24.04
    wsl -d Ubuntu-24.04 -e bash -c "wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && bash ~/miniconda.sh -b -p ~/miniconda && echo 'export PATH=\"~/miniconda/bin:\$PATH\"' >> ~/.bashrc && ~/miniconda/bin/conda init bash"
    wsl -d Ubuntu-24.04 -e bash -c "sudo apt update && sudo apt upgrade -y"

# mkcert is a simple tool for making locally-trusted development certificates. It requires no configuration.
winget install mkcert --accept-package-agreements --accept-source-agreements --silent

winget install "Node.js (LTS)" --accept-package-agreements --accept-source-agreements --silent

winget install Notepad++.Notepad++ --accept-package-agreements --accept-source-agreements --silent

winget install Python.Python.3.9 --accept-package-agreements --accept-source-agreements --silent
    %LOCALAPPDATA%\Programs\Python\Python39\python.exe -m pip install --upgrade pip
# winget install Python.Python.3.10 --accept-package-agreements --accept-source-agreements --silent
# winget install Python.Python.3.11 --accept-package-agreements --accept-source-agreements --silent
# winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements --silent
# winget install Python.Python.3.13 --accept-package-agreements --accept-source-agreements --silent

winget install Yarn.Yarn

# Windows Notepad (9MSMLRH6LZF3 is the MSSTORE installation)
winget install 9MSMLRH6LZF3 --accept-package-agreements --accept-source-agreements --silent

winget install Discord.Discord --accept-package-agreements --accept-source-agreements --silent

winget install OpenWhisperSystems.Signal --accept-package-agreements --accept-source-agreements --silent

winget install VideoLAN.VLC --accept-package-agreements --accept-source-agreements --silent

winget install ffmpeg --accept-package-agreements --accept-source-agreements --silent

winget upgrade --all
```
