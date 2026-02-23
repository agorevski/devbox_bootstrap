---
name: security-audit
description: |
  Performs a comprehensive security audit of a software project. Covers secrets
  scanning, dependency vulnerabilities, OWASP Top 10, container security, IaC
  security, and code quality security issues. Produces a severity-classified
  findings report with concrete remediation steps.
  
  Trigger phrases:
  - "run a security audit"
  - "security review this project"
  - "scan for vulnerabilities"
  - "check for secrets or hardcoded credentials"
  - "audit dependencies for CVEs"
  - "security check before release"
  - "find security issues in this repo"
---

# Security Audit Skill

You are performing a structured security audit of a software project. Work through each phase below in order — quick wins first, deeper analysis later. Collect all findings as you go and emit the final report at the end.

Maintain a mental (or session-db) list of findings, each with:
- **ID** (e.g. SEC-001)
- **Severity**: Critical / High / Medium / Low / Informational
- **Category**
- **Location** (file:line or tool output)
- **Description**
- **Remediation**

---

## Phase 0 — Orientation

Before scanning, understand the project shape:

```bash
# Detect languages / stacks present
ls -1 *.sln *.csproj 2>/dev/null && echo "dotnet detected"
ls -1 package.json 2>/dev/null && echo "nodejs detected"
ls -1 requirements.txt pyproject.toml setup.py setup.cfg 2>/dev/null && echo "python detected"
ls -1 go.mod 2>/dev/null && echo "go detected"
ls -1 Cargo.toml 2>/dev/null && echo "rust detected"
ls -1 Dockerfile* docker-compose*.yml 2>/dev/null && echo "docker detected"
ls -1 *.tf 2>/dev/null && echo "terraform detected"
ls -1 *.bicep 2>/dev/null && echo "bicep detected"
find . -name "*.yaml" -o -name "*.yml" | xargs grep -l "kind: " 2>/dev/null | head -5 && echo "k8s manifests detected"
```

Skip irrelevant phases based on what is present.

---

## Phase 1 — Secrets & Credential Scanning

### 1a. Quick pattern scan (no tools required)

```bash
# Hardcoded secrets — common patterns
grep -rn --include="*.{cs,py,js,ts,json,yaml,yml,xml,config,env,tf,bicep,sh,ps1}" \
  -E "(password|passwd|pwd|secret|api[_-]?key|apikey|token|connection.?string|accountkey|client[_-]?secret)\s*[=:]\s*['\"][^'\"]{6,}" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | grep -v "example\|sample\|placeholder\|changeme\|your-" \
  | head -40

# Azure-specific: storage account keys, SAS tokens, connection strings
grep -rn --include="*.{cs,py,js,ts,json,yaml,yml,config,env}" \
  -E "(DefaultEndpointsProtocol|AccountKey=|SharedAccessSignature|sv=|sig=)" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# AWS keys (common even in Azure shops)
grep -rn -E "AKIA[0-9A-Z]{16}" . 2>/dev/null | grep -v ".git/" | head -10
```

### 1b. Check .gitignore hygiene

```bash
# Files that should NOT be committed
for f in .env .env.local .env.production .env.development \
         appsettings.Production.json secrets.json \
         terraform.tfvars terraform.tfvars.json \
         *.pfx *.p12 *.key *.pem id_rsa id_ed25519; do
  git ls-files --error-unmatch "$f" 2>/dev/null && echo "WARNING: $f is tracked by git"
done

# Check .gitignore covers common secret files
cat .gitignore 2>/dev/null || echo "No .gitignore found — HIGH finding"
```

### 1c. Git history scan

```bash
# Secrets committed then removed (still in history)
git log --all --oneline -100 2>/dev/null | head -5  # confirm git repo

# Use trufflehog if available
trufflehog git file://. --only-verified 2>/dev/null \
  || trufflehog filesystem . 2>/dev/null \
  || echo "trufflehog not available — install: pip install trufflehog3 or brew install trufflehog"

# Use gitleaks if available
gitleaks detect --source . --no-git 2>/dev/null \
  || gitleaks detect --source . 2>/dev/null \
  || echo "gitleaks not available — install: https://github.com/gitleaks/gitleaks"

# Manual history grep for high-signal patterns (slow on large repos — limit depth)
git log --all -p --max-count=200 2>/dev/null \
  | grep -E "^\+" \
  | grep -iE "(password|secret|api.?key|token|accountkey)\s*[=:]\s*['\"][^'\"]{8,}" \
  | grep -v "example\|sample\|placeholder" \
  | head -20
```

### 1d. Configuration file audit

```bash
# appsettings.json — look for non-placeholder values in sensitive keys
find . -name "appsettings*.json" ! -name "*.Development.*" | xargs grep -l \
  -iE "password|secret|key|token|connectionstring" 2>/dev/null

# Azure Key Vault usage check — are secrets being fetched from KV or hardcoded?
grep -rn "KeyVaultClient\|SecretClient\|AddAzureKeyVault" --include="*.cs" . 2>/dev/null | head -5
grep -rn "AZURE_CLIENT_SECRET\|AZURE_TENANT_ID" --include="*.{env,yaml,yml,json}" . 2>/dev/null \
  | grep -v ".git/" | head -10
```

---

## Phase 2 — Dependency Vulnerability Scanning

Run whichever scanners match detected stacks. Capture output — CVEs with Critical/High severity are automatic High/Critical findings.

### Node.js

```bash
# npm audit — standard
npm audit --json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
vulns = d.get('vulnerabilities', {})
for name, v in vulns.items():
    sev = v.get('severity','?').upper()
    if sev in ('CRITICAL','HIGH','MODERATE'):
        print(f'[{sev}] {name}: {v.get(\"title\",\"\")}')" 2>/dev/null \
  || npm audit 2>/dev/null | head -60

# Check for outdated lockfile
[ -f package-lock.json ] || [ -f yarn.lock ] || [ -f pnpm-lock.yaml ] \
  || echo "WARNING: No lockfile — dependency versions unpinned"
```

### Python

```bash
# pip-audit (preferred)
pip-audit --format=json 2>/dev/null | python3 -c "
import sys, json
for v in json.load(sys.stdin).get('dependencies',[]):
    for vuln in v.get('vulns',[]):
        print(f'[HIGH] {v[\"name\"]} {v[\"version\"]}: {vuln[\"id\"]} {vuln[\"description\"][:100]}')" \
  || pip-audit 2>/dev/null \
  || echo "pip-audit not available: pip install pip-audit"

# safety (alternative)
safety check 2>/dev/null || echo "safety not available: pip install safety"
```

### .NET

```bash
# dotnet list package --vulnerable (requires .NET SDK)
find . -name "*.sln" -o -name "*.csproj" | head -5 | while read f; do
  echo "=== $f ==="
  dotnet list "$f" package --vulnerable --include-transitive 2>/dev/null
done
```

### Go

```bash
# govulncheck (official)
govulncheck ./... 2>/dev/null || echo "govulncheck not available: go install golang.org/x/vuln/cmd/govulncheck@latest"

# nancy
go list -m -json all 2>/dev/null | nancy sleuth 2>/dev/null \
  || echo "nancy not available: https://github.com/sonatype-oss/nancy"
```

### Rust

```bash
cargo audit 2>/dev/null || echo "cargo-audit not available: cargo install cargo-audit"
```

### Container images

```bash
# Trivy — scans image layers for OS and app CVEs
# Run against each Dockerfile's expected image tag or a built image
for img in $(grep -r "^FROM" Dockerfile* 2>/dev/null | awk '{print $2}' | sort -u); do
  echo "=== Trivy: $img ==="
  trivy image --severity HIGH,CRITICAL "$img" 2>/dev/null \
    || echo "trivy not available: https://aquasecurity.github.io/trivy"
done
```

---

## Phase 3 — OWASP Top 10 Quick Check

These require code inspection. Look for patterns; flag for manual review where automated detection is insufficient.

### A01 — Broken Access Control

```bash
# Missing authorization attributes (.NET)
grep -rn --include="*.cs" -E "\[HttpGet|HttpPost|HttpPut|HttpDelete|HttpPatch" . \
  | grep -v "Authorize\|AllowAnonymous" 2>/dev/null | head -20

# Direct object references without ownership check
grep -rn --include="*.{cs,py,js,ts}" -E "FindById\|GetById\|\.Find\(id\)" . \
  | grep -v ".git/" | grep -v "node_modules/" | head -20
```

### A02 — Cryptographic Failures

```bash
# Weak hashing (MD5, SHA1 for passwords)
grep -rn --include="*.{cs,py,js,ts}" -iE "MD5\.(Create|Hash)|SHA1\.(Create|Hash)|hashlib\.md5|hashlib\.sha1|createHash\('md5'\)|createHash\('sha1'\)" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# HTTP (not HTTPS) URLs hardcoded
grep -rn --include="*.{cs,py,js,ts,json,yaml,yml,config}" \
  -E '"http://[^l]' . 2>/dev/null \
  | grep -v ".git/" | grep -v "node_modules/" | grep -v "localhost\|127\.0\." | head -20

# TLS validation disabled
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "ServerCertificateValidationCallback|verify=False|rejectUnauthorized: false|checkServerIdentity" \
  . 2>/dev/null | grep -v ".git/" | head -20
```

### A03 — Injection

```bash
# SQL injection patterns — string concatenation in queries
grep -rn --include="*.{cs,py,js,ts}" \
  -E '(SELECT|INSERT|UPDATE|DELETE|WHERE).*\+\s*("|'"'"'|[a-zA-Z_])|f".*SELECT|f".*WHERE|string\.Format.*SELECT' \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# Command injection
grep -rn --include="*.{cs,py,js,ts}" \
  -E "Process\.Start|subprocess\.(call|run|Popen)|child_process\.(exec|spawn)|shell=True" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# LDAP injection
grep -rn --include="*.cs" -E "DirectorySearcher|LdapConnection" . 2>/dev/null | head -10
```

### A04 — Security Misconfiguration

```bash
# Debug mode / detailed errors in production config
grep -rn --include="*.{json,yaml,yml,config,xml}" \
  -iE '"debug"\s*:\s*true|Debug\s*=\s*true|ASPNETCORE_ENVIRONMENT.*Development|customErrors.*Off' \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# CORS — wildcard origin
grep -rn --include="*.{cs,py,js,ts,json,yaml,yml}" \
  -iE 'AllowAnyOrigin\(\)|cors.*\*|origin.*\*' \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# Default/sample credentials in config
grep -rn --include="*.{json,yaml,yml,config,xml,env}" \
  -iE '(admin|root|password|123456|changeme|test|demo)\s*["\x27]?\s*[,}]' \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20
```

### A07 — Identification & Authentication Failures

```bash
# JWT — none algorithm, no expiry, HS256 with weak secret
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "algorithm.*none|JwtSecurityTokenHandler.*ValidateSignature.*false|expiresIn.*[0-9]{6}" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -10

# Password stored in plain text
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "\.Password\s*=|password\s*=\s*[a-zA-Z_]" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" \
  | grep -v "hash\|bcrypt\|argon\|scrypt\|pbkdf" | head -20
```

### A09 — Security Logging & Monitoring Failures

```bash
# Sensitive data logged
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "(log|logger|console)\.(info|debug|warn|error|write).*password|log.*token|log.*secret" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20
```

---

## Phase 4 — Docker / Container Security

```bash
# Scan each Dockerfile
for df in $(find . -name "Dockerfile*" ! -path "*/.git/*"); do
  echo "=== $df ==="
  
  # Running as root (no USER directive, or USER root)
  if ! grep -q "^USER " "$df" || grep -q "^USER root" "$df"; then
    echo "  [HIGH] No non-root USER directive found"
  fi

  # COPY . . or ADD . . (may include secrets)
  grep -n "^COPY \. \.\|^ADD \. \." "$df" && echo "  [MEDIUM] Broad COPY/ADD — verify .dockerignore excludes secrets"

  # Secrets in ENV or ARG
  grep -niE "^(ENV|ARG).*(password|secret|key|token)" "$df" \
    && echo "  [HIGH] Potential secret in ENV/ARG — use build secrets or runtime env injection"

  # Latest tag (unpinned base image)
  grep -E "^FROM.*:latest" "$df" && echo "  [MEDIUM] Unpinned :latest base image"

  # Package manager cache left in layer
  grep -n "apt-get install\|apk add\|yum install" "$df" \
    | grep -v "\-\-no-cache\|rm -rf /var/lib/apt" \
    && echo "  [LOW] Package manager cache may be left in image layer"
done

# .dockerignore present?
[ -f .dockerignore ] || echo "[MEDIUM] No .dockerignore — secrets/dev files may be included in build context"
grep -l ".env\|*.pem\|*.key\|secrets" .dockerignore 2>/dev/null || echo "[LOW] .dockerignore may not exclude secret files"

# Trivy filesystem scan (catches secrets in image layers)
trivy fs --severity HIGH,CRITICAL . 2>/dev/null | head -60 \
  || echo "trivy not available for filesystem scan"
```

---

## Phase 5 — Infrastructure as Code Security

### Terraform

```bash
find . -name "*.tf" | head -3 | while read f; do echo "Found: $f"; done

# tfsec
tfsec . 2>/dev/null | grep -E "CRITICAL|HIGH|WARNING" | head -40 \
  || echo "tfsec not available: https://github.com/aquasecurity/tfsec"

# checkov (also covers Terraform)
checkov -d . --framework terraform --compact --quiet 2>/dev/null | head -40 \
  || echo "checkov not available: pip install checkov"

# Manual: overly permissive IAM
grep -rn --include="*.tf" -E '"[*]"|\*\s*$' . | grep -i "action\|principal\|effect.*Allow" | head -20
```

### Bicep / ARM

```bash
# checkov for Bicep/ARM
checkov -d . --framework bicep arm --compact --quiet 2>/dev/null | head -40

# Manual: public network access, no HTTPS enforcement
grep -rn --include="*.{bicep,json}" \
  -iE "publicNetworkAccess.*Enabled|httpsOnly.*false|allowBlobPublicAccess.*true" \
  . 2>/dev/null | grep -v ".git/" | head -20
```

### Kubernetes Manifests

```bash
find . -name "*.yaml" -o -name "*.yml" | xargs grep -l "kind:" 2>/dev/null > /tmp/k8s_files.txt

# kubesec
cat /tmp/k8s_files.txt | while read f; do
  result=$(kubesec scan "$f" 2>/dev/null)
  [ -n "$result" ] && echo "=== $f ===" && echo "$result" | python3 -c "
import sys, json
for r in json.load(sys.stdin):
    score = r.get('score', 0)
    if score < 0:
        print(f'  Score {score} — FAILING rules:')
        for item in r.get('scoring',{}).get('critical',[]):
            print(f'    [CRITICAL] {item.get(\"id\")}: {item.get(\"reason\")}')" 2>/dev/null
done

# Manual checks
cat /tmp/k8s_files.txt | xargs grep -l "" | while read f; do
  # privileged containers
  grep -n "privileged: true" "$f" && echo "  [CRITICAL] Privileged container in $f"
  # hostNetwork / hostPID
  grep -n "hostNetwork: true\|hostPID: true" "$f" && echo "  [HIGH] hostNetwork/hostPID in $f"
  # runAsRoot or missing runAsNonRoot
  grep -n "runAsUser: 0" "$f" && echo "  [HIGH] Running as root (UID 0) in $f"
  # no resource limits
  grep -L "limits:" "$f" 2>/dev/null && echo "  [MEDIUM] No resource limits in $f"
  # RBAC — cluster-admin bindings
  grep -n "cluster-admin" "$f" && echo "  [HIGH] cluster-admin role binding in $f"
done

rm -f /tmp/k8s_files.txt
```

---

## Phase 6 — Code Quality Security Issues

```bash
# Path traversal
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "Path\.Combine.*Request|File\.Read.*user|open\(.*request\.|readFile.*req\." \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# Insecure deserialization
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "JsonConvert\.DeserializeObject|pickle\.loads|yaml\.load\([^,)]*\)|eval\(|new Function\(" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# Error messages exposing internals (stack traces to client)
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "exception\.Message|exception\.StackTrace|traceback\.print_exc|res\.send.*err\.|res\.json.*error:" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# Logging sensitive request data
grep -rn --include="*.{cs,py,js,ts}" \
  -iE "log.*Request\.Form|log.*body\.|log.*password|log.*Authorization" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -20

# Regex DoS (ReDoS) — catastrophic backtracking patterns
grep -rn --include="*.{cs,py,js,ts}" \
  -E "new Regex\(|re\.compile\(|\/\(" \
  . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | head -10
```

---

## Phase 7 — Generate Findings Report

After completing all phases, compile and emit the following report structure. Fill in actual findings discovered above; omit empty severity levels.

```
# Security Audit Report
**Date:** [today's date]
**Repository:** [repo name / path]
**Auditor:** GitHub Copilot Security Audit Skill

---

## Executive Summary
[2-3 sentence overview: number of findings by severity, most critical areas]

---

## Findings

### 🔴 CRITICAL

| ID | Category | Location | Description |
|----|----------|----------|-------------|
| SEC-001 | Secrets | src/config.js:42 | AWS API key hardcoded in source |

**Remediation:**
- Remove secret immediately, rotate the credential in the provider console
- Add to .gitignore and use environment variables or Azure Key Vault
- If in git history: use `git filter-repo` or BFG Repo Cleaner to purge

---

### 🟠 HIGH

| ID | Category | Location | Description |
|----|----------|----------|-------------|
| ... | ... | ... | ... |

**Remediation:**
[specific steps per finding]

---

### 🟡 MEDIUM

| ID | Category | Location | Description |
|----|----------|----------|-------------|
| ... | ... | ... | ... |

---

### 🔵 LOW / INFORMATIONAL

| ID | Category | Location | Description |
|----|----------|----------|-------------|
| ... | ... | ... | ... |

---

## Remediation Priority

1. **Immediate (24h):** Rotate any exposed credentials found in source or history
2. **Short-term (1 week):** Patch Critical/High CVEs in dependencies; fix container root issues
3. **Medium-term (1 sprint):** Address OWASP findings; implement missing authorization checks
4. **Long-term:** Integrate automated scanning into CI/CD pipeline (see below)

---

## Recommended CI/CD Integrations

| Tool | Purpose | Config |
|------|---------|--------|
| gitleaks | Secret scanning on every commit | `.gitleaks.toml` + pre-commit hook or GitHub Action |
| trivy | Container + dependency CVE scanning | `aquasecurity/trivy-action` in GitHub Actions |
| npm audit / pip-audit / dotnet vulnerable | Dep scanning per stack | Run in CI on PR |
| checkov / tfsec | IaC scanning | Run on Terraform/Bicep changes |
| OWASP ZAP / Burp Suite | DAST on staging environment | Weekly scheduled scan |

---

## Notes
- This audit covers static analysis and pattern matching. Manual penetration testing is recommended for critical systems.
- Azure-specific: Ensure all secrets are stored in Azure Key Vault; use Managed Identities to eliminate credential management where possible.
- Enable Microsoft Defender for DevOps (GitHub Advanced Security or Azure DevOps) for continuous scanning.
```

---

## Tips for the Auditor (Claude)

- **Don't stop at first match** — many findings will be false positives. Use judgment: is this a real secret or a placeholder?
- **Check context** — a `password` variable assigned from `Environment.GetEnvironmentVariable(...)` is fine; one assigned a string literal is not.
- **Prioritize ruthlessly** — a hardcoded production database password outweighs 50 Medium findings. Lead with impact.
- **Be specific in remediation** — name the exact file, line, variable, and the exact fix (e.g. "replace line 42 with `Environment.GetEnvironmentVariable("DB_PASSWORD")`").
- **Note tool gaps** — if a recommended tool wasn't available, say so and suggest how to install it.
- **Rotate, don't just remove** — if a real secret is found, removal from code is not enough; the credential must be rotated.
