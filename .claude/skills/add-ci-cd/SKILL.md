---
name: add-ci-cd
description: |
  Adds GitHub Actions CI/CD pipelines to a project. Detects the tech stack,
  asks clarifying questions, then generates production-ready workflow YAML for
  CI (build/test/lint) and CD (deploy to Azure). Covers .NET, Python, Node.js,
  Go, Rust, and Docker. Designed for Windows developers using Azure, AKS, and
  Azure Functions.
triggers:
  - "add CI/CD"
  - "set up GitHub Actions"
  - "add pipeline"
  - "add workflows"
  - "set up CI"
  - "configure deployment pipeline"
  - "add ci cd"
  - "github actions"
---

# Skill: Add GitHub Actions CI/CD Pipelines

## Overview

This skill creates `.github/workflows/ci.yml` and `.github/workflows/cd.yml`
tailored to the project's tech stack and Azure deployment target. It also
provides secrets guidance, OIDC federation setup, branch protection rules,
and README status badges.

---

## Step 1 — Detect Tech Stack

Inspect the repository root for the following files to identify the stack.
Multiple stacks may be present (e.g. a .NET API + React frontend).

| File / Pattern                              | Stack          |
|---------------------------------------------|----------------|
| `*.csproj`, `*.sln`, `global.json`          | .NET           |
| `requirements.txt`, `pyproject.toml`, `Pipfile`, `setup.py` | Python |
| `package.json`                              | Node.js        |
| `go.mod`                                    | Go             |
| `Cargo.toml`                                | Rust           |
| `Dockerfile`, `docker-compose.yml`          | Docker         |
| `Chart.yaml`, `helmfile.yaml`               | Helm / AKS     |
| `*.bicep`, `*.tf`                           | IaC (Azure)    |

```
# Commands to run during detection
ls -1
find . -maxdepth 3 -name "*.csproj" -o -name "go.mod" -o -name "Cargo.toml" \
       -o -name "package.json" -o -name "pyproject.toml" -o -name "requirements.txt" \
       | head -40
cat package.json 2>/dev/null | python3 -m json.tool 2>/dev/null | grep '"scripts"' -A 20
```

Report findings to the user before asking questions.

---

## Step 2 — Ask Clarifying Questions

Ask all questions at once in a numbered list. Wait for answers before
generating any YAML.

```
I found the following stack(s): <detected stacks>

Before I generate the workflows, I need a few answers:

1. **Triggers** — Which events should run CI?
   a) Push to `main` only
   b) Push to `main` + pull requests
   c) Push to `main`, PRs, and version tags (`v*.*.*`)
   d) Custom (describe)

2. **Environments** — Which deployment environments do you use?
   (e.g. dev, staging, prod — or just prod)

3. **Deploy target** — Where does the app run after a successful build?
   a) Azure App Service
   b) Azure Kubernetes Service (AKS) — kubectl or Helm?
   c) Azure Functions
   d) Docker registry only (GHCR / ACR / Docker Hub)
   e) No deployment needed (CI only)

4. **Matrix testing** — Do you need to test across multiple OS or
   language versions? (e.g. ubuntu + windows, Python 3.12 + 3.13)

5. **Coverage reporting** — Codecov, Azure artifacts, or skip?

6. **Azure subscription / resource names** (for CD):
   - Azure region (e.g. `eastus`)
   - Resource group name
   - App Service / AKS / Function App name
   - Container registry URL (if applicable, e.g. `myacr.azurecr.io`)
```

---

## Step 3 — Generate CI Workflow

Create `.github/workflows/ci.yml`. Use the detected stack(s) to build the
correct job steps. The template below shows all sections; remove unused ones.

### 3a — Trigger block (fill in from Q1)

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  # Add if user chose tags:
  # push:
  #   tags: ["v*.*.*"]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
```

### 3b — .NET job

```yaml
jobs:
  dotnet:
    name: .NET Build & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "9.x"   # adjust to project's global.json version

      - name: Cache NuGet packages
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
          restore-keys: ${{ runner.os }}-nuget-

      - name: Restore dependencies
        run: dotnet restore

      - name: Check formatting
        run: dotnet format --verify-no-changes

      - name: Build
        run: dotnet build --no-restore --configuration Release

      - name: Test with coverage
        run: |
          dotnet test --no-build --configuration Release \
            --collect:"XPlat Code Coverage" \
            --results-directory ./coverage

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: dotnet-coverage
          path: ./coverage
```

### 3c — Python job

```yaml
  python:
    name: Python Lint & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.13"   # adjust as needed

      - name: Cache pip
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt', '**/pyproject.toml') }}
          restore-keys: ${{ runner.os }}-pip-

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          # Choose ONE of:
          pip install -r requirements.txt
          # pip install -e ".[dev]"          # pyproject.toml with extras
          # pip install poetry && poetry install

      - name: Lint (pylint + mypy)
        run: |
          pip install pylint mypy
          pylint src/        # adjust path
          mypy src/          # adjust path

      - name: Test with coverage
        run: |
          pip install pytest pytest-cov
          pytest --cov=src --cov-report=xml

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: coverage.xml
```

### 3d — Node.js job

```yaml
  nodejs:
    name: Node.js Lint & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Lint (ESLint)
        run: npm run lint

      - name: Build
        run: npm run build --if-present

      - name: Test with coverage
        run: npm test -- --coverage

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: node-coverage
          path: coverage/
```

### 3e — Go job

```yaml
  go:
    name: Go Build & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          cache: true

      - name: golangci-lint
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest

      - name: Build
        run: go build ./...

      - name: Test with coverage
        run: go test -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: go-coverage
          path: coverage.out
```

### 3f — Rust job

```yaml
  rust:
    name: Rust Check & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Rust toolchain
        uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt

      - name: Cache Cargo
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/bin/
            ~/.cargo/registry/index/
            ~/.cargo/registry/cache/
            ~/.cargo/git/db/
            target/
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}

      - name: Check formatting
        run: cargo fmt --all -- --check

      - name: Clippy
        run: cargo clippy --all-targets --all-features -- -D warnings

      - name: Build
        run: cargo build --release

      - name: Test
        run: cargo test --all-features
```

### 3g — Matrix testing (if Q4 = yes)

Wrap the relevant job in a matrix strategy:

```yaml
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
        # python-version: ["3.11", "3.13"]   # uncomment for Python matrix
    runs-on: ${{ matrix.os }}
```

### 3h — Dependency review (for PRs)

Add this job to `ci.yml` to automatically flag new dependencies with known
vulnerabilities on pull requests:

```yaml
  dependency-review:
    name: Dependency Review
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high
```

### 3i — Dependabot Configuration

Create `.github/dependabot.yml` to keep GitHub Actions versions and project
dependencies up to date automatically:

```yaml
# .github/dependabot.yml
version: 2
updates:
  # Keep GitHub Actions up to date
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns: ["*"]

  # --- Add ONE of the following blocks for the detected stack ---

  # .NET (NuGet)
  # - package-ecosystem: "nuget"
  #   directory: "/"
  #   schedule:
  #     interval: "weekly"

  # Python (pip)
  # - package-ecosystem: "pip"
  #   directory: "/"
  #   schedule:
  #     interval: "weekly"

  # Node.js (npm)
  # - package-ecosystem: "npm"
  #   directory: "/"
  #   schedule:
  #     interval: "weekly"

  # Go (gomod)
  # - package-ecosystem: "gomod"
  #   directory: "/"
  #   schedule:
  #     interval: "weekly"

  # Rust (cargo)
  # - package-ecosystem: "cargo"
  #   directory: "/"
  #   schedule:
  #     interval: "weekly"

  # Docker
  # - package-ecosystem: "docker"
  #   directory: "/"
  #   schedule:
  #     interval: "weekly"
```

Uncomment the block(s) matching the detected stack.

---

## Step 4 — Generate CD Workflow

Create `.github/workflows/cd.yml`. Use environment protection rules so each
environment requires manual approval (configure in GitHub repo settings →
Environments).

### 4a — Common CD preamble

```yaml
name: CD

on:
  push:
    branches: [main]
  # workflow_dispatch allows manual runs from the Actions tab
  workflow_dispatch:

concurrency:
  group: cd-${{ github.ref }}
  cancel-in-progress: false

permissions:
  id-token: write   # required for OIDC
  contents: read

jobs:
```

### 4b — Azure App Service deploy

```yaml
  deploy-app-service:
    name: Deploy to Azure App Service
    runs-on: ubuntu-latest
    environment: production   # links to GitHub Environment

    steps:
      - uses: actions/checkout@v4

      # ---- OIDC login (preferred) ----
      - name: Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # ---- .NET publish + deploy ----
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "9.x"

      - name: Publish
        run: dotnet publish --configuration Release --output ./publish

      - name: Deploy to App Service
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ secrets.AZURE_APP_NAME }}
          package: ./publish

      # ---- Node.js variant ----
      # - name: Build
      #   run: npm ci && npm run build
      # - name: Deploy to App Service
      #   uses: azure/webapps-deploy@v3
      #   with:
      #     app-name: ${{ secrets.AZURE_APP_NAME }}
      #     package: ./dist
```

### 4c — Azure Kubernetes Service (kubectl)

```yaml
  deploy-aks:
    name: Deploy to AKS
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Get AKS credentials
        uses: azure/aks-set-context@v4
        with:
          resource-group: ${{ secrets.AZURE_RESOURCE_GROUP }}
          cluster-name: ${{ secrets.AKS_CLUSTER_NAME }}

      - name: Build and push Docker image
        run: |
          az acr login --name ${{ secrets.ACR_NAME }}
          docker buildx build \
            --platform linux/amd64,linux/arm64 \
            -t ${{ secrets.ACR_NAME }}.azurecr.io/myapp:${{ github.sha }} \
            --push .

      - name: Deploy with kubectl
        run: |
          kubectl set image deployment/myapp \
            myapp=${{ secrets.ACR_NAME }}.azurecr.io/myapp:${{ github.sha }}
          kubectl rollout status deployment/myapp
```

### 4d — AKS with Helm

```yaml
      - name: Helm upgrade
        run: |
          helm upgrade --install myapp ./charts/myapp \
            --namespace default \
            --set image.repository=${{ secrets.ACR_NAME }}.azurecr.io/myapp \
            --set image.tag=${{ github.sha }} \
            --wait --timeout 5m
```

### 4e — Azure Functions

```yaml
  deploy-functions:
    name: Deploy to Azure Functions
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # ---- .NET Functions ----
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "9.x"

      - name: Build
        run: dotnet build --configuration Release --output ./output

      - name: Deploy
        uses: Azure/functions-action@v1
        with:
          app-name: ${{ secrets.AZURE_FUNCTIONAPP_NAME }}
          package: ./output
          # respect-pom-xml: true   # for Java
```

### 4f — Docker registry only (GHCR)

```yaml
  push-image:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        id: push
        uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Attest build provenance
        uses: actions/attest-build-provenance@v2
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

---

## Step 5 — Branch Protection Rules

After creating the workflows, recommend these settings (GitHub → Settings →
Branches → Add rule for `main`):

```
Branch name pattern: main

✅ Require a pull request before merging
   ✅ Require approvals: 1 (or 2 for prod repos)
   ✅ Dismiss stale pull request approvals when new commits are pushed

✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging
   — Add the job names from ci.yml as required checks, e.g.:
       • dotnet
       • python
       • nodejs
       • go
       • rust

✅ Require conversation resolution before merging
✅ Do not allow bypassing the above settings
```

---

## Step 6 — GitHub Secrets to Configure

Go to GitHub → Settings → Secrets and variables → Actions → New repository secret.

### Always required (OIDC path)

| Secret name              | Value / How to get it                                   |
|--------------------------|---------------------------------------------------------|
| `AZURE_CLIENT_ID`        | App registration client ID (see Step 7)                 |
| `AZURE_TENANT_ID`        | Azure AD tenant ID (`az account show --query tenantId`) |
| `AZURE_SUBSCRIPTION_ID`  | Subscription ID (`az account show --query id`)          |

### Deployment-specific

| Secret name              | When needed                          |
|--------------------------|--------------------------------------|
| `AZURE_APP_NAME`         | App Service deploy                   |
| `AZURE_RESOURCE_GROUP`   | AKS deploy                           |
| `AKS_CLUSTER_NAME`       | AKS deploy                           |
| `ACR_NAME`               | ACR push (without `.azurecr.io`)     |
| `AZURE_FUNCTIONAPP_NAME` | Functions deploy                     |
| `CODECOV_TOKEN`          | Codecov coverage upload              |

### Optional environment variables (use vars, not secrets)

| Variable name            | Example value    |
|--------------------------|------------------|
| `AZURE_REGION`           | `eastus`         |
| `DOTNET_VERSION`         | `9.0`            |
| `NODE_VERSION`           | `22`             |

---

## Step 7 — OIDC Federation Setup (Preferred over Service Principals)

OIDC eliminates long-lived credentials. Follow these steps:

```bash
# 1. Create an app registration
az ad app create --display-name "github-actions-<repo-name>"

# 2. Note the appId from output, then create a service principal
APP_ID=<appId from above>
az ad sp create --id $APP_ID

# 3. Add federated credential for the main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<org>/<repo>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 4. (Optional) Add federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<org>/<repo>:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 5. Assign a role (scope to resource group, not subscription, where possible)
OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)
az role assignment create \
  --assignee-object-id $OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope /subscriptions/<sub-id>/resourceGroups/<resource-group>
```

Then set `AZURE_CLIENT_ID` = `$APP_ID` as a GitHub secret.

> **Security note:** The `id-token: write` permission in the workflow is
> required for OIDC. Scope it only to jobs that need Azure access.

---

## Step 8 — Add Status Badges to README

Append (or prepend) the following to `README.md`, replacing placeholders:

```markdown
## Status

[![CI](https://github.com/<org>/<repo>/actions/workflows/ci.yml/badge.svg)](https://github.com/<org>/<repo>/actions/workflows/ci.yml)
[![CD](https://github.com/<org>/<repo>/actions/workflows/cd.yml/badge.svg)](https://github.com/<org>/<repo>/actions/workflows/cd.yml)
```

---

## Step 9 — Final Checklist

Before committing, verify:

- [ ] `.github/workflows/ci.yml` contains only jobs for detected stacks
- [ ] `.github/workflows/cd.yml` targets the correct Azure resource type
- [ ] All `secrets.XXX` references match the secret names in Step 6
- [ ] `permissions:` blocks are as narrow as possible
- [ ] Environments in `cd.yml` match environments created in GitHub Settings
- [ ] Branch protection rules are configured
- [ ] OIDC federated credential subject matches the exact branch/event pattern

---

## Reusable Workflow Pattern

For organizations with multiple repositories sharing the same CI logic, extract
the CI job into a **reusable workflow** with `workflow_call:`.

### Create the reusable workflow (e.g. `.github/workflows/ci-reusable.yml`)

```yaml
name: Reusable CI

on:
  workflow_call:
    inputs:
      dotnet-version:
        required: false
        type: string
        default: "9.x"
      node-version:
        required: false
        type: string
        default: "22"
      python-version:
        required: false
        type: string
        default: "3.13"

permissions:
  contents: read

jobs:
  build-and-test:
    name: Build & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Add the stack-specific steps here (same as ci.yml jobs)
      # e.g. setup-dotnet, restore, build, test
```

### Call from the same repo (`ci.yml`)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    uses: ./.github/workflows/ci-reusable.yml
    with:
      dotnet-version: "9.x"
```

### Call from another repository

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    uses: <org>/.github/.github/workflows/ci-reusable.yml@main
    with:
      dotnet-version: "9.x"
```

> **Note:** Cross-repo reusable workflows must live in a `.github` repository
> or the calling repo must have access. The reusable workflow must be in a
> public repo or the same organization with internal visibility.

---

## Troubleshooting

### `Error: The token has been granted the 'read' permission`
The job is missing `permissions: id-token: write`. Add it to the job or
top-level workflow.

### `Secret not found` / empty secret value
Secrets are not available in forks by default. For PRs from forks, use
environment secrets with approval gates instead of repository secrets.

### Runner can't find `dotnet` / `node` / `go`
Always use a `setup-*` action before calling the tool. Never rely on the
pre-installed version without pinning it — it changes with runner images.

### `az login` fails with `AADSTS70021`
The federated credential subject doesn't match. Common mismatch: using
`refs/heads/main` in the subject but the workflow fires on a PR
(`pull_request` event). Create separate federated credentials per trigger.

### `kubectl: command not found`
Add `azure/setup-kubectl@v4` before the kubectl step, or use
`azure/aks-set-context@v4` which installs kubectl automatically.

### Docker push: `unauthorized: authentication required`
For GHCR, ensure `packages: write` is in `permissions`. For ACR, run
`az acr login --name <acr-name>` after the Azure login step.

### Helm: `Error: INSTALLATION FAILED: rendered manifests contain a resource that already exists`
Add `--force` to the `helm upgrade` command, or use `--atomic` to roll back
on failure automatically.

### Slow builds / cache misses
Verify the cache key includes the correct lockfile hash. For NuGet use
`hashFiles('**/*.csproj')`, for npm use `hashFiles('**/package-lock.json')`,
for pip use `hashFiles('**/requirements*.txt')`.
