---
name: code-review
description: >
  Conduct a thorough, structured code review across architecture, security,
  performance, quality, tests, docs, and ops. Works for PRs, branch diffs,
  staged changes, or individual files.
triggers:
  - "review this PR"
  - "code review"
  - "review my changes"
  - "review this branch"
  - "review these files"
  - "give me a code review"
  - "can you review"
---

# Code Review Skill

Conduct a systematic, constructive code review. Follow each phase in order.
Be thorough but proportional — major concerns get more depth than nitpicks.

---

## Phase 1 — Establish Review Scope

Before reviewing anything, clarify what to review and why.

**Determine the target:**
- PR? → `gh pr view <number>` then `gh pr diff <number>`
- Branch diff? → `git diff main...<feature-branch>` (three-dot for branch-only changes)
- Staged changes? → `git diff --staged`
- Specific files? → `git diff HEAD -- <file1> <file2>` or read files directly

**Understand the intent:**
- If reviewing a PR, read the description: `gh pr view <number>`
- If no description exists, ask: *"What is the purpose of this change?"*
- Read any linked issue if referenced

**Get file context:**
- For changed files, read surrounding code (not just the diff) to understand existing patterns
- Note the language(s), framework(s), and architectural style in use

---

## Phase 2 — Architecture & Design Review

Ask these questions for every significant change:

- **Pattern alignment**: Does the change follow existing conventions (naming, file structure, abstractions)? If it deviates, is there a good reason?
- **Single responsibility**: Do new functions/classes/modules do one thing? Are concerns mixed?
- **Abstraction level**: Are abstractions appropriate — not too leaky, not over-engineered?
- **Complexity**: Is there unnecessary complexity? Could the same result be achieved more simply?
- **Backwards compatibility**: Does the change break any existing public interfaces, API contracts, or data formats?
- **Coupling**: Does the change introduce tight coupling between components that should be independent?

---

## Phase 3 — Security Review

Check every change for security implications:

- **Input validation**: Is all external input (user input, API responses, file contents, env vars) validated and sanitized before use?
- **Auth checks**: Are authentication and authorization enforced at the right boundaries? Are there missing permission checks?
- **Injection risks**: SQL injection (raw queries, string interpolation), command injection (shell calls), template injection, path traversal
- **Sensitive data**: Are secrets, PII, or tokens being logged, serialized to disk, or returned in responses where they shouldn't be?
- **Dependencies**: Are any new dependencies introduced? If so, are they well-maintained and free of known CVEs? (`gh` can help check: look for `package.json`, `go.mod`, `requirements.txt` changes)
- **Error messages**: Do error messages leak internal details (stack traces, file paths, DB schema) to untrusted callers?

---

## Phase 4 — Performance Review

Identify performance concerns proportional to the code's expected load:

- **N+1 queries**: Loops that trigger DB queries or network calls per iteration — look for queries inside `for`/`forEach`/`map` loops
- **Memory**: Unnecessary large allocations, data loaded entirely into memory when streaming would work, missing resource cleanup (`defer`, `finally`, `using`)
- **Caching**: Repeated expensive computations or I/O with no caching where caching would be safe and beneficial
- **Algorithm complexity**: O(n²) or worse where O(n log n) or O(n) is achievable (nested loops over large collections, repeated linear scans)
- **Database**: Missing indexes on columns used in `WHERE`/`JOIN`/`ORDER BY`, fetching more columns than needed (`SELECT *`)
- **Concurrency**: Race conditions, missing locks, or blocking calls on hot paths

---

## Phase 5 — Code Quality

Review the code itself for readability and correctness:

- **Naming**: Are variables, functions, and classes named clearly and accurately? Avoid single-letter names outside tight loops, avoid misleading names
- **Function length/complexity**: Functions longer than ~50 lines or with cyclomatic complexity > 10 are candidates for extraction
- **Magic values**: Unexplained literals (`42`, `"admin"`, `86400`) should be named constants
- **Error handling**: Are all error paths handled? Are errors propagated with context? Are errors silently swallowed?
- **Null/nil/undefined**: Are nullable values checked before dereferencing? Are there potential NPEs / nil pointer dereferences?
- **DRY**: Is logic duplicated that could be extracted into a shared function or utility?
- **Dead code**: Commented-out code, unused imports, unreachable branches

---

## Phase 6 — Test Coverage

Evaluate tests for the changed code:

- **Coverage of new paths**: Every new function and significant branch should have at least one test
- **Edge cases**: Empty inputs, zero values, maximum values, concurrent access, error conditions
- **Test quality**: Tests should assert behavior, not implementation details. Avoid tests that only check "it didn't throw"
- **Mocking**: Are mocks appropriate? Over-mocking can make tests pass while real behavior is broken
- **Test naming**: Test names should describe the scenario and expected outcome, not just the method name
- **Flakiness**: Tests that depend on timing, global state, or external services without proper isolation

If tests are missing for changed behavior, flag it as a **Must Fix** or **Should Fix** depending on criticality.

---

## Phase 7 — Documentation

Check that documentation is accurate and complete:

- **Public APIs**: New or changed public functions/methods/endpoints should have docstrings or comments explaining parameters, return values, and side effects
- **Complex logic**: Non-obvious algorithms or business rules should have an explanatory comment
- **README**: If the change affects setup, configuration, or usage, is the README updated?
- **Changelog**: If the project maintains a CHANGELOG, is this entry added?
- **Breaking changes**: Are breaking changes clearly documented? Is a migration path provided?

---

## Phase 8 — Operational Concerns

For production code, consider operability:

- **Logging**: Are important events logged at appropriate levels? Avoid logging sensitive data. Avoid excessive debug logging in hot paths
- **Observability**: Are new code paths instrumented with metrics/traces where the system already uses them?
- **Configuration**: Are new config values externalised (env vars, config files) rather than hardcoded? Are defaults safe?
- **Database migrations**: Are migrations reversible? Do they lock tables? Are they safe to run on a live database with existing data?
- **Deployment**: Does the change require a specific deployment order (e.g., migrate DB before deploying code)?
- **Feature flags**: For large or risky changes, is there a rollout mechanism?

---

## Phase 9 — Generate Review Report

Compile findings into a structured report. Use this format exactly:

```
## Code Review: <PR title / branch / description>

### 🔴 Must Fix
Issues that are bugs, security vulnerabilities, data loss risks, or correctness
failures. Must be resolved before merging.

- **[File:Line]** Description of the issue and why it matters.
  Suggested fix or direction.

### 🟡 Should Fix
Strong improvements that aren't blocking but represent real quality or
maintainability concerns.

- **[File:Line]** Description and suggestion.

### 🔵 Consider
Optional improvements worth thinking about — refactors, better patterns,
alternative approaches.

- **[File:Line]** Description and suggestion.

### 🔸 Nitpicks
Minor style, naming, or formatting issues. Low priority.

- **[File:Line]** Brief note.

### ✅ Praise
Specific things done well. Be genuine — this isn't filler.

- **[File:Line]** What's good and why.

---
**Summary**: <2–3 sentence overall assessment. Recommend: Approve / Approve with
minor comments / Request changes.>
```

**Guidelines for findings:**
- Always include a file and line reference when possible
- Explain *why* something is a problem, not just *what* it is
- Offer a concrete suggestion or direction for every Must Fix and Should Fix
- Be proportional: a 5-line change shouldn't have 20 nitpicks

---

## Phase 10 — Post Review Actions

After generating the report, offer to submit it via GitHub CLI if reviewing a PR.

**Leave a review comment:**
```bash
# Request changes
gh pr review <number> --request-changes --body "<review text>"

# Approve
gh pr review <number> --approve --body "<review text>"

# Comment only (no approval decision)
gh pr review <number> --comment --body "<review text>"
```

**Inline comments on specific lines:**
```bash
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --method POST \
  --field body="<comment>" \
  --field commit_id="<sha>" \
  --field path="<file>" \
  --field line=<line_number> \
  --field side="RIGHT"
```

Ask the user: *"Would you like me to submit this review via `gh pr review`?"*
If yes, use `--request-changes` for any Must Fix items, `--approve` only if the
report is clean or contains only nitpicks/praise.
