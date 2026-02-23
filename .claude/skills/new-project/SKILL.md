---
name: new-project
description: >
  Scaffolds a new project from scratch for Windows developers using the
  devbox_bootstrap environment. Supports .NET, Python, Node.js/TypeScript,
  React, Go, and Rust. Handles git, GitHub, Docker, CI, auth, and database
  wiring automatically based on answers to upfront questions.
triggers:
  - "scaffold a new project"
  - "create a new project"
  - "new project"
  - "start a new project"
  - "bootstrap a project"
  - "initialize a new project"
  - "set up a new project"
  - "create a new app"
---

# Skill: Scaffold a New Project

## Overview

This skill scaffolds a production-ready project skeleton from scratch. It asks
all clarifying questions upfront, then executes the full scaffold automatically
without further interruption.

---

## Step 1 — Gather Requirements (ask ALL questions before doing any work)

Present the following questions to the user **in a single message**. Do not
begin any file creation or commands until all answers are received.

```
I'll scaffold your project. Please answer the following questions:

1. **Project name** (kebab-case recommended, e.g. `my-cool-api`):

2. **Short description** (one sentence — used in README and package metadata):

3. **Tech stack** — choose one:
   a) .NET Web API
   b) .NET Console App
   c) Python FastAPI
   d) Python CLI
   e) Node.js / TypeScript API (Express or Fastify)
   f) React App (Vite + TypeScript)
   g) Go CLI or API
   h) Rust CLI

4. **Database** — choose one:
   a) PostgreSQL
   b) SQLite
   c) MongoDB
   d) Azure Cosmos DB
   e) None

5. **Authentication** — choose one:
   a) Azure AD (MSAL / Microsoft.Identity.Web)
   b) JWT (self-issued)
   c) None

6. **Docker?** (yes / no)
   - Generates Dockerfile + docker-compose.yml + .dockerignore

7. **GitHub repository?** — choose one:
   a) Create a new GitHub repo (public or private?)
   b) Use an existing remote (provide the URL)
   c) Local only (no GitHub)
```

Wait for all answers before proceeding.

---

## Step 2 — Determine Working Directory

```
Where should the project be created?
Default: current working directory → <cwd>/<project-name>/
(Press Enter to accept, or provide an absolute path.)
```

Create the project root directory and `cd` into it for all subsequent steps.

---

## Step 3 — Stack-Specific Scaffold

Execute the commands and create the files for the chosen stack.

### 3a — .NET Web API

```bash
dotnet new webapi -n {ProjectName} --use-controllers --output .
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.Console
dotnet add package FluentValidation.AspNetCore
```

If database ≠ None:
```bash
dotnet add package Microsoft.EntityFrameworkCore
dotnet add package Microsoft.EntityFrameworkCore.Design
# PostgreSQL:
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
# SQLite:
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
# Cosmos DB:
dotnet add package Microsoft.EntityFrameworkCore.Cosmos
```

If auth = Azure AD:
```bash
dotnet add package Microsoft.Identity.Web
```

If auth = JWT:
```bash
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

**Directory structure to create** (beyond what `dotnet new` generates):
```
Controllers/
Services/
Models/
Data/          ← only if database chosen
```

**`appsettings.json`** — add a `ConnectionStrings` section (if DB) and an
`AzureAd` or `Jwt` section (if auth). Add `"Serilog"` config block.

**`appsettings.Development.json`** — safe dev defaults; never commit secrets.

Create **`README.md`** (see Step 6).

---

### 3b — .NET Console App

```bash
dotnet new console -n {ProjectName} --output .
dotnet add package Serilog
dotnet add package Serilog.Sinks.Console
dotnet add package Microsoft.Extensions.Configuration.Json
dotnet add package Microsoft.Extensions.DependencyInjection
dotnet add package Microsoft.Extensions.Hosting
```

Rewrite `Program.cs` to use `Host.CreateDefaultBuilder` with DI and Serilog.

**Directory structure:**
```
Services/
Models/
```

---

### 3c — Python FastAPI

```bash
python -m venv .venv
source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install fastapi "uvicorn[standard]" pydantic pydantic-settings python-dotenv
pip install --dev pytest httpx pytest-asyncio
pip freeze > requirements.txt
```

**Directory structure:**
```
{project_name}/
  main.py
  routers/
    __init__.py
  models/
    __init__.py
  services/
    __init__.py
  core/
    __init__.py
    config.py      ← pydantic-settings BaseSettings
tests/
  __init__.py
  test_main.py
```

**`main.py`** — create a minimal FastAPI app with lifespan, CORS middleware,
and the routers mounted.

**`.env.example`** — list all env vars with placeholder values.

**`pyproject.toml`** (preferred) or keep `requirements.txt` if simpler:
```toml
[project]
name = "{project-name}"
version = "0.1.0"
description = "{description}"
requires-python = ">=3.11"
```

If database = PostgreSQL: `pip install asyncpg sqlalchemy[asyncio] alembic`
If database = SQLite: `pip install aiosqlite sqlalchemy[asyncio] alembic`
If database = MongoDB: `pip install motor beanie`
If database = Cosmos DB: `pip install azure-cosmos`

If auth = Azure AD: `pip install msal`
If auth = JWT: `pip install python-jose[cryptography] passlib[bcrypt]`

---

### 3d — Python CLI

```bash
python -m venv .venv
source .venv/bin/activate
pip install click rich python-dotenv
pip install --dev pytest
pip freeze > requirements.txt
```

**Directory structure:**
```
{project_name}/
  __init__.py
  cli.py         ← click group entry point
  commands/
    __init__.py
  utils/
    __init__.py
tests/
  __init__.py
```

**`pyproject.toml`** with `[project.scripts]` entry pointing at the click group.

---

### 3e — Node.js / TypeScript API

```bash
npm init -y
npm install express
npm install -D typescript ts-node-dev @types/node @types/express eslint prettier
npx tsc --init
```

Or with Fastify:
```bash
npm install fastify @fastify/cors
```

**`tsconfig.json`** — set `"target": "ES2022"`, `"module": "commonjs"`,
`"outDir": "dist"`, `"rootDir": "src"`, `"strict": true`,
`"paths": { "@/*": ["src/*"] }`.

**`package.json` scripts:**
```json
"scripts": {
  "dev": "ts-node-dev --respawn --transpile-only src/index.ts",
  "build": "tsc",
  "start": "node dist/index.js",
  "test": "jest"
}
```

**Directory structure:**
```
src/
  index.ts
  routes/
  services/
  models/
  middleware/
tests/
```

**`.eslintrc.json`** and **`.prettierrc`** with sensible defaults.

If database = PostgreSQL: `npm install pg && npm install -D @types/pg`
If database = SQLite: `npm install better-sqlite3 && npm install -D @types/better-sqlite3`
If database = MongoDB: `npm install mongoose`
If database = Cosmos DB: `npm install @azure/cosmos`

If auth = Azure AD: `npm install @azure/msal-node`
If auth = JWT: `npm install jsonwebtoken && npm install -D @types/jsonwebtoken`

---

### 3f — React App (Vite + TypeScript)

```bash
npm create vite@latest . -- --template react-ts
npm install
npm install -D eslint prettier eslint-plugin-react eslint-config-prettier
```

**`vite.config.ts`** — add path alias:
```ts
resolve: {
  alias: { '@': path.resolve(__dirname, 'src') }
}
```

**`tsconfig.json`** — add matching `"paths": { "@/*": ["src/*"] }`.

**`.eslintrc.cjs`** and **`.prettierrc`** with sensible defaults.

---

### 3g — Go CLI or API

```bash
go mod init github.com/{github-username}/{project-name}
```

For API, install a router:
```bash
go get github.com/go-chi/chi/v5          # preferred lightweight router
# or: go get github.com/gin-gonic/gin
```

For CLI:
```bash
go get github.com/spf13/cobra
go get github.com/spf13/viper
```

If database = PostgreSQL: `go get github.com/jackc/pgx/v5`
If database = SQLite: `go get modernc.org/sqlite`
If database = MongoDB: `go get go.mongodb.org/mongo-driver/mongo`
If database = Cosmos DB: `go get github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos`

**Standard layout:**
```
cmd/
  {project-name}/
    main.go
internal/
  handlers/      ← API only
  services/
  models/
  repository/    ← only if DB chosen
pkg/             ← exported reusable code
configs/
  config.go      ← viper-based config
```

---

### 3h — Rust CLI

```bash
cargo new {project-name} --bin
cd {project-name}
```

Add to **`Cargo.toml`** under `[dependencies]`:
```toml
clap = { version = "4", features = ["derive"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
anyhow = "1"
tokio = { version = "1", features = ["full"] }   # if async needed
```

**`src/main.rs`** — scaffold a `clap` derive-based CLI with a root `Cli` struct
and a `Commands` enum.

---

## Step 4 — Universal Setup (all stacks)

### 4a — .gitignore

Generate a `.gitignore` appropriate for the chosen stack using the standard
gitignore templates. Always include:
- Stack-specific patterns (bin/, obj/, __pycache__/, node_modules/, target/, etc.)
- `.env` (never commit secrets)
- `.venv/`, `.idea/`, `.vs/`, `.vscode/` (local tooling)
- `*.user`, `*.suo`, `Thumbs.db`, `.DS_Store`

### 4b — .editorconfig

Create `.editorconfig` at the project root:
```ini
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{js,ts,tsx,jsx,json,yml,yaml,html,css,scss}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

### 4c — README.md

```markdown
# {ProjectName}

{description}

## Prerequisites

List the required runtime versions, tools, and environment variables.

## Setup

Step-by-step setup instructions (clone, install deps, configure env).

## Running

How to run locally (dev mode and production).

## Testing

How to run the test suite.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
```

### 4d — CONTRIBUTING.md

```markdown
# Contributing

## Getting Started

1. Fork the repository and clone your fork.
2. Create a feature branch: `git checkout -b feat/your-feature`.
3. Make your changes and add tests.
4. Run the test suite and linter.
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/).
6. Open a pull request.

## Commit Convention

Format: `<type>(<scope>): <subject>`
Types: feat, fix, docs, chore, refactor, test, ci

## Code Style

Describe linter / formatter commands for this stack.
```

### 4e — Pre-commit Hooks

**JavaScript / TypeScript stacks** (React, Node.js):
```bash
npm install -D husky lint-staged
npx husky init
echo "npx lint-staged" > .husky/pre-commit
```
Add to `package.json`:
```json
"lint-staged": {
  "*.{ts,tsx,js}": ["eslint --fix", "prettier --write"],
  "*.{json,md,yml}": ["prettier --write"]
}
```

**Python stacks**:
```bash
pip install pre-commit
```
Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
```
```bash
pre-commit install
```

**All other stacks (.NET, Go, Rust)** — create `.git/hooks/pre-commit` shell
script that runs the relevant formatter/linter:
- .NET: `dotnet format --verify-no-changes`
- Go: `gofmt -l . && golangci-lint run`
- Rust: `cargo fmt --check && cargo clippy -- -D warnings`

### 4f — GitHub Actions CI Workflow

Create `.github/workflows/ci.yml` tailored to the stack:

**.NET:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.x' }
      - run: dotnet restore
      - run: dotnet build --no-restore
      - run: dotnet test --no-build
```

**Python:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.13' }
      - run: pip install -r requirements.txt
      - run: pytest
      - run: ruff check .
```

**Node.js / React:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm run build
      - run: npm test
```

**Go:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.23' }
      - run: go build ./...
      - run: go test ./...
      - run: go vet ./...
```

**Rust:**
```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo build
      - run: cargo test
      - run: cargo clippy -- -D warnings
      - run: cargo fmt --check
```

### 4g — LICENSE

Ask the user which license to use (default: MIT):

```
Which open-source license? (default: MIT)
a) MIT
b) Apache-2.0
c) GPL-3.0
d) BSD-3-Clause
e) No license / proprietary
```

For MIT, create `LICENSE` with the standard MIT text and current year + user's name.
For others, use the standard SPDX text from https://choosealicense.com.
For proprietary, create `LICENSE` with: "Copyright (c) {year} {org}. All rights reserved."

### 4h — SECURITY.md

```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| latest  | ✅ |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** open a public GitHub issue.
2. Email [security@example.com] with details of the vulnerability.
3. Include steps to reproduce, impact assessment, and suggested fix if possible.
4. You will receive a response within 48 hours.

We follow [coordinated vulnerability disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure).
```

Update the email address placeholder to match the project/org.

### 4i — GitHub Issue & PR Templates

Create `.github/ISSUE_TEMPLATE/bug_report.md`:
```markdown
---
name: Bug Report
about: Report a bug to help us improve
labels: bug
---

## Description
A clear description of the bug.

## Steps to Reproduce
1. Go to '...'
2. Click on '...'
3. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- OS: [e.g., Windows 11]
- Version: [e.g., v1.2.0]
```

Create `.github/ISSUE_TEMPLATE/feature_request.md`:
```markdown
---
name: Feature Request
about: Suggest a new feature
labels: enhancement
---

## Problem
Describe the problem this feature would solve.

## Proposed Solution
Describe your preferred solution.

## Alternatives Considered
Any alternative approaches you've considered.
```

Create `.github/pull_request_template.md`:
```markdown
## What
Brief description of the change.

## Why
Motivation and context.

## How
Key implementation decisions.

## Testing
How was this tested?

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or migration guide provided)
```

### 4j — Dependabot & CODEOWNERS

Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
  # Add the relevant ecosystem:
  # - package-ecosystem: "npm"         # Node.js
  # - package-ecosystem: "pip"         # Python
  # - package-ecosystem: "nuget"       # .NET
  # - package-ecosystem: "gomod"       # Go
  # - package-ecosystem: "cargo"       # Rust
  #   directory: "/"
  #   schedule:
  #     interval: "weekly"
```

Create `CODEOWNERS`:
```
# Default owner for everything
* @{github-username}
```

---

## Step 5 — Git Initialization

```bash
git init
git add -A
git commit -m "chore: initial project scaffold

Generated by new-project skill.
Stack: {stack}
Database: {database}
Auth: {auth}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**If GitHub repo = Create new:**
```bash
gh repo create {project-name} --{public|private} --source=. --remote=origin --push
```

Set default branch protection (requires GitHub CLI ≥ 2.40):
```bash
gh api repos/{owner}/{project-name}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["build"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

**If GitHub repo = Use existing:**
```bash
git remote add origin {provided-url}
git push -u origin main
```

**If GitHub repo = Local only:** skip remote steps.

---

## Step 6 — Docker Setup (if Docker = yes)

### Dockerfile

Generate a multi-stage `Dockerfile` appropriate for the stack:

**.NET:**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "{ProjectName}.dll"]
```

**Python:**
```dockerfile
FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "{project_name}.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Node.js:**
```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY package*.json .
RUN npm ci --omit=dev
CMD ["node", "dist/index.js"]
```

**Go:**
```dockerfile
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.* .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app ./cmd/{project-name}

FROM gcr.io/distroless/static
COPY --from=build /app /app
ENTRYPOINT ["/app"]
```

**Rust:**
```dockerfile
FROM rust:1.83-slim AS build
WORKDIR /src
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
COPY --from=build /src/target/release/{project-name} /usr/local/bin/
ENTRYPOINT ["{project-name}"]
```

### docker-compose.yml

Generate a `docker-compose.yml` that includes:
- The app service using the local `Dockerfile`
- A database service matching the chosen DB (postgres, mongo, etc.) — omit if
  database = None
- An `env_file: [.env]` reference on the app service

### .dockerignore

Generate `.dockerignore` excluding build artifacts, env files, test output, and
local tooling directories appropriate for the stack.

---

## Step 7 — Final Summary

After all steps complete, print the following summary:

```
✅ Project scaffold complete!

📁 Project: {project-name}  ({absolute-path})
🔧 Stack:   {stack}
🗄  Database: {database}
🔐 Auth:    {auth}
🐳 Docker:  {yes/no}
🐙 GitHub:  {repo-url or "local only"}

Files created:
  • README.md, CONTRIBUTING.md, SECURITY.md, LICENSE, .editorconfig, .gitignore
  • .github/workflows/ci.yml
  • .github/ISSUE_TEMPLATE/bug_report.md, .github/ISSUE_TEMPLATE/feature_request.md
  • .github/pull_request_template.md
  • .github/dependabot.yml, CODEOWNERS
  • {stack-specific source files listed here}
  {• Dockerfile, docker-compose.yml, .dockerignore  ← if Docker}
  {• .pre-commit-config.yaml  ← if Python}
  {• .husky/  ← if JS/TS}

🚀 Next steps:
  1. cd {project-name}
  2. Copy .env.example → .env and fill in secrets  (if applicable)
  3. {Stack-specific run command, e.g. "dotnet run" / "uvicorn ..." / "npm run dev"}
  4. Open {repo-url} to review the repository  (if GitHub)
```
