---
name: dockerize
description: >
  Adds Docker containerization to an existing project. Generates Dockerfile (multi-stage),
  .dockerignore, docker-compose.yml, and docker-compose.override.yml tailored to the
  detected tech stack.
triggers:
  - "dockerize this project"
  - "add Docker support"
  - "containerize this app"
  - "create a Dockerfile"
  - "set up docker-compose"
  - "add container support"
---

# Skill: Dockerize an Existing Project

## Overview

This skill adds complete Docker containerization to an existing project. It detects the
tech stack, generates appropriate multi-stage Dockerfiles with best practices, a
`.dockerignore`, a `docker-compose.yml` for development, a `docker-compose.override.yml`
for local overrides, and optionally wires in companion services (PostgreSQL, Redis,
MongoDB).

---

## Step 0 — Ask Clarifying Questions

Before generating any files, ask the user:

1. **Tech stack** – If not immediately obvious from project files, ask:
   > "What language/framework is this project? (.NET, Python, Node.js, Go, Rust, Java, other)"

2. **Focus** – Dev, prod, or both?
   > "Should I optimize for development (hot-reload, debugger) or production (minimal image size), or generate both?"

3. **Companion services** – Which optional services are needed?
   > "Do you need any companion services? (PostgreSQL, Redis, MongoDB, none)"

4. **Registry** – For push instructions:
   > "Where will images be pushed? (Docker Hub, Azure Container Registry, skip)"

5. **App port** – What port does the application listen on?
   > "What port does your app listen on? (default: 8080)"

Proceed once you have (or can infer) answers to the above.

---

## Step 1 — Detect Tech Stack

Inspect the project root for these indicator files:

| File(s) found | Stack |
|---|---|
| `*.csproj`, `*.sln`, `global.json` | .NET |
| `requirements.txt`, `pyproject.toml`, `Pipfile`, `setup.py` | Python |
| `package.json` + no `*.csproj` | Node.js |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pom.xml`, `build.gradle` | Java |

Note the **framework** within the stack (e.g., ASP.NET vs console, FastAPI vs Django,
Express vs Next.js) because it affects the run command and health-check path.

---

## Step 2 — Generate `.dockerignore`

Create `.dockerignore` in the project root. Use the stack-specific template below.

### .NET
```
**/.git
**/.vs
**/.idea
**/obj
**/bin
**/out
**/*.user
**/*.suo
**/node_modules
**/.env
**/.env.*
**/Dockerfile*
**/docker-compose*
**/README*
```

### Python
```
**/.git
**/__pycache__
**/*.pyc
**/*.pyo
**/.venv
**/venv
**/.env
**/.env.*
**/.mypy_cache
**/.pytest_cache
**/dist
**/build
**/*.egg-info
**/node_modules
**/Dockerfile*
**/docker-compose*
```

### Node.js
```
**/.git
**/node_modules
**/npm-debug.log
**/.env
**/.env.*
**/dist
**/build
**/.next
**/.nuxt
**/*.log
**/coverage
**/Dockerfile*
**/docker-compose*
```

### Go
```
**/.git
**/vendor
**/*.test
**/*.out
**/.env
**/.env.*
**/tmp
**/Dockerfile*
**/docker-compose*
```

### Rust
```
**/.git
**/target
**/.env
**/.env.*
**/Dockerfile*
**/docker-compose*
```

---

## Step 3 — Generate `Dockerfile`

Use multi-stage builds. Always:
- Name stages (`AS builder`, `AS runtime`)
- Run as a non-root user in the final stage
- Pin base image tags (never use `latest` in production)
- Place `COPY` of dependency manifests before source to maximize layer caching

### .NET (SDK → aspnet runtime)
```dockerfile
# syntax=docker/dockerfile:1
ARG DOTNET_VERSION=9.0
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS builder
WORKDIR /src

# Restore dependencies (cached layer)
COPY ["*.csproj", "./"]
RUN dotnet restore

# Build & publish
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# ── Runtime ──────────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS runtime
WORKDIR /app

# Non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

COPY --from=builder /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "<AssemblyName>.dll"]
```
> Replace `<AssemblyName>` with the actual DLL name from the `.csproj`.

---

### Python (slim image)
```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.13-slim AS builder
WORKDIR /app

# Install dependencies in an isolated prefix for copying
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Runtime ──────────────────────────────────────────────────────────────────
FROM python:3.13-slim AS runtime
WORKDIR /app

# Non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

COPY --from=builder /install /usr/local
COPY --chown=appuser:appgroup . .

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```
> Adjust the CMD for your framework: `gunicorn`, `flask run`, `python app.py`, etc.

---

### Node.js (npm ci, dev/prod deps split)
```dockerfile
# syntax=docker/dockerfile:1
FROM node:22-slim AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:22-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build          # remove if no build step

# ── Runtime ──────────────────────────────────────────────────────────────────
FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Non-root user (node image ships with 'node' user uid=1000)
COPY --from=deps   --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist         ./dist
COPY --chown=node:node package*.json ./
USER node

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', r => process.exit(r.statusCode===200?0:1))"

CMD ["node", "dist/index.js"]
```
> Adjust `dist/index.js` to match your build output entry point.

---

### Go (multi-stage → distroless)
```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.23-alpine AS builder
WORKDIR /src

# Cache module downloads
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /app ./cmd/server

# ── Runtime ──────────────────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot AS runtime
COPY --from=builder /app /app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD ["/app", "-healthcheck"]

ENTRYPOINT ["/app"]
```
> Adjust `./cmd/server` to your main package path. If the binary does not support a
> `-healthcheck` flag, remove that line and use an external curl-based check or switch
> the base image to `distroless/base` which includes a shell.

---

### Rust (musl → scratch)
```dockerfile
# syntax=docker/dockerfile:1
FROM rust:1.83-slim AS builder
WORKDIR /src

# Install musl target for fully static binary
RUN rustup target add x86_64-unknown-linux-musl \
 && apt-get update && apt-get install -y musl-tools && rm -rf /var/lib/apt/lists/*

# Cache dependency compilation
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main(){}" > src/main.rs \
 && cargo build --release --target x86_64-unknown-linux-musl \
 && rm -rf src

COPY src ./src
RUN touch src/main.rs \
 && cargo build --release --target x86_64-unknown-linux-musl

# ── Runtime ──────────────────────────────────────────────────────────────────
FROM scratch AS runtime
COPY --from=builder /src/target/x86_64-unknown-linux-musl/release/<binary-name> /app

EXPOSE 8080

ENTRYPOINT ["/app"]
```
> Replace `<binary-name>` with the name defined in `Cargo.toml` `[[bin]]` or the package name.

---

## Step 4 — Generate `docker-compose.yml` (Development Base)

```yaml
# docker-compose.yml  —  base configuration (dev + prod shared settings)
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime          # override to "builder" for debug images
    image: ${IMAGE_NAME:-myapp}:${IMAGE_TAG:-latest}
    ports:
      - "${APP_PORT:-8080}:8080"
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
    # Adjust limits per your app's requirements. Remove for local dev if too restrictive.
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 512M
        reservations:
          cpus: "0.5"
          memory: 128M
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  # ── PostgreSQL ────────────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER:-app}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-secret}
      POSTGRES_DB: ${DB_NAME:-appdb}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "${DB_PORT:-5432}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-app}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # ── Redis ─────────────────────────────────────────────────────────────────
  cache:
    image: redis:7-alpine
    command: redis-server --save 60 1 --loglevel warning
    volumes:
      - redis_data:/data
    ports:
      - "${REDIS_PORT:-6379}:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```
> Remove the `db` and `cache` services (and their volumes) if companion services were not
> requested. Remove `depends_on` entries for services you removed.

---

## Step 5 — Generate `docker-compose.override.yml` (Dev Overrides)

This file is automatically merged by Docker Compose in dev and should **not** be committed
to production CI/CD pipelines (add it to `.gitignore` if desired, or leave it versioned
for team dev environments).

```yaml
# docker-compose.override.yml  —  local development overrides (not for prod)
services:
  app:
    build:
      target: builder         # mount source into build stage for hot-reload
    volumes:
      - .:/app                # live source mount
      - /app/node_modules     # anonymous volume keeps container node_modules
    environment:
      - NODE_ENV=development  # or ASPNETCORE_ENVIRONMENT=Development, etc.
      - LOG_LEVEL=debug
    command: npm run dev      # hot-reload command; adjust per stack
```

Stack-specific `command` overrides:

| Stack | Dev command |
|---|---|
| .NET | `dotnet watch run` |
| Python | `uvicorn main:app --reload --host 0.0.0.0 --port 8080` |
| Node.js | `npm run dev` (assumes nodemon or similar) |
| Go | Install `air` in builder stage; `air` |
| Rust | `cargo watch -x run` |

---

## Step 5.5 — Secrets Management

Never bake secrets into images. Use one of these approaches:

### Development: `.env` file (already configured)
The `env_file: [.env]` directive in `docker-compose.yml` injects secrets at runtime.

### Production: Docker secrets (Swarm) or external secret managers

For Docker Compose (v3.1+) with file-based secrets:
```yaml
services:
  app:
    secrets:
      - db_password
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt    # local dev
    # external: true                    # Docker Swarm / production
```

For Kubernetes: use `Secret` objects mounted as volumes or env vars.
For Azure: use Azure Key Vault with Managed Identity — never store secrets in AKS ConfigMaps.

### Build-time secrets (Docker BuildKit)
```bash
# Pass secrets during build without baking them into layers
DOCKER_BUILDKIT=1 docker build \
  --secret id=npm_token,src=$HOME/.npmrc \
  -t myapp .
```

In Dockerfile:
```dockerfile
RUN --mount=type=secret,id=npm_token,target=/root/.npmrc npm ci
```

---

## Step 6 — Generate `.env` Template

Create `.env.example` (committed) and `.env` (gitignored):

```dotenv
# Application
APP_PORT=8080
IMAGE_NAME=myapp
IMAGE_TAG=latest

# Database
DB_USER=app
DB_PASSWORD=changeme
DB_PASSWORD_PROD=REPLACE_WITH_STRONG_PASSWORD
DB_NAME=appdb
DB_PORT=5432

# Cache
REDIS_PORT=6379

# Stack-specific
# ASPNETCORE_ENVIRONMENT=Development
# DATABASE_URL=postgresql://app:changeme@db:5432/appdb
# REDIS_URL=redis://cache:6379
```

Add to `.gitignore`:
```
.env
.env.local
.env.*.local
```

---

## Step 7 — Build & Run Commands

Provide these commands to the user:

```bash
# Copy env template
cp .env.example .env
# Edit .env with real values

# Build image
docker compose build

# Start all services (detached)
docker compose up -d

# View logs
docker compose logs -f app

# Run one-off command inside the container
docker compose run --rm app <command>

# Stop all services
docker compose down

# Stop and remove volumes (destructive)
docker compose down -v
```

---

## Step 8 — Multi-Architecture Build (buildx)

```bash
# Create a builder with multi-platform support (once)
docker buildx create --name multiarch --use

# Build and push for AMD64 + ARM64
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag <registry>/<image>:<tag> \
  --push \
  .
```

---

## Step 8.5 — Security Scanning

### Scan built images for vulnerabilities
```bash
# Trivy (recommended)
trivy image myapp:latest --severity HIGH,CRITICAL

# Docker Scout (built into Docker Desktop)
docker scout cves myapp:latest
docker scout recommendations myapp:latest

# Grype (alternative)
grype myapp:latest
```

### Integrate scanning into CI
```yaml
# Add to .github/workflows/ci.yml
  scan:
    name: Container Security Scan
    runs-on: ubuntu-latest
    needs: [build]
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-results.sarif
```

### Image signing and attestation
```bash
# Sign images with cosign (Sigstore)
cosign sign --yes ghcr.io/org/myapp:latest

# Verify signature
cosign verify ghcr.io/org/myapp:latest
```

---

## Step 9 — Registry Push

### Docker Hub
```bash
docker login
docker tag myapp:latest <dockerhub-username>/myapp:latest
docker push <dockerhub-username>/myapp:latest
```

### Azure Container Registry (ACR)
```bash
az acr login --name <acr-name>
docker tag myapp:latest <acr-name>.azurecr.io/myapp:latest
docker push <acr-name>.azurecr.io/myapp:latest
```

---

## Troubleshooting

### Build fails — "file not found" or "COPY failed"
- Verify paths in `COPY` relative to `context` in `docker-compose.yml`.
- Check `.dockerignore` isn't excluding required source files.
- Run `docker build --progress=plain .` for verbose layer output.

### Container crashes immediately
```bash
docker compose logs app          # read exit message
docker compose run --rm app sh   # get a shell (use bash if sh absent)
```
- Confirm the `CMD`/`ENTRYPOINT` binary path is correct.
- Confirm env variables (connection strings, ports) are set in `.env`.

### "Port already in use"
- Change `APP_PORT` in `.env`, or stop the conflicting process:
  ```bash
  lsof -i :<port>
  ```

### Database connection refused from app container
- Use the **service name** (`db`, `cache`) as the hostname, not `localhost`.
- Confirm `depends_on` with `condition: service_healthy` is set.
- Check `DB_USER`/`DB_PASSWORD` match between app env and postgres env.

### Volume permission errors (Linux hosts)
```bash
# Option A — match UID in Dockerfile
RUN addgroup --gid 1000 appgroup && adduser --uid 1000 --ingroup appgroup appuser

# Option B — fix ownership at startup (less ideal)
docker compose run --rm --user root app chown -R appuser:appgroup /app
```

### Hot-reload not working
- Confirm the source volume mount in `docker-compose.override.yml` covers the right path.
- Some watchers (webpack, nodemon) need `CHOKIDAR_USEPOLLING=true` on Linux/WSL:
  ```yaml
  environment:
    - CHOKIDAR_USEPOLLING=true
  ```

### Image too large
- Use `docker image inspect <image>` and `docker history <image>` to identify big layers.
- Prefer `-slim` or `-alpine` base images.
- Ensure build artifacts (`/src`, `/root/.cargo`, `target/`) are **not** copied into the
  runtime stage.

### Multi-arch build fails for native dependencies
- Use `--platform` in the `FROM` line when cross-compiling:
  ```dockerfile
  FROM --platform=$BUILDPLATFORM golang:1.23 AS builder
  ARG TARGETOS TARGETARCH
  RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build ...
  ```

### DNS resolution failures inside containers
```bash
# Test DNS from inside a container
docker compose exec app nslookup db

# Fix: add DNS config to docker-compose.yml
services:
  app:
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

### Build context too large / slow builds
```bash
# Check what's being sent to the daemon
du -sh $(docker buildx inspect --bootstrap 2>/dev/null || echo ".")

# Ensure .dockerignore excludes large directories:
# .git, node_modules, .venv, target/, bin/, obj/
```
