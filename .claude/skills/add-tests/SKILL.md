---
name: add-tests
description: >
  Add a test suite to an existing project. Detects the tech stack, sets up
  the appropriate testing framework, generates real test code for key
  functions/classes, configures coverage reporting, and wires up pre-commit
  hooks. Supports .NET, Python, Node.js/TypeScript, Go, and Rust.
---

# Skill: Add Tests

## Phase 1 — Detect Existing Test Setup

Before asking any questions, scan the repository to understand what already exists.

### 1.1 Stack Detection

Run these checks in parallel:

```
# .NET
ls *.sln **/*.csproj 2>/dev/null
grep -r "xunit\|nunit\|mstest" **/*.csproj 2>/dev/null

# Python
ls pytest.ini pyproject.toml setup.cfg tox.ini tests/ 2>/dev/null
grep -r "pytest\|unittest" pyproject.toml setup.cfg 2>/dev/null

# Node / TypeScript
ls package.json vitest.config.* jest.config.* 2>/dev/null
grep -E '"test"|vitest|jest' package.json 2>/dev/null

# Go
ls go.mod go.sum 2>/dev/null
find . -name '*_test.go' 2>/dev/null | head -5

# Rust
ls Cargo.toml 2>/dev/null
grep '\[dev-dependencies\]' Cargo.toml 2>/dev/null
```

Determine:
- Primary language / framework
- Whether a test project / directory already exists
- Which test framework is already in use (if any)
- Rough count of existing test files

### 1.2 Report findings

Tell the user what you found, e.g.:

> "I found a .NET solution with 3 projects. No `*.Tests` project exists yet.
> No test runner references detected."

---

## Phase 2 — Ask Clarifying Questions

Ask **all** questions at once (do not drip them one-by-one):

1. **Test type(s):** unit, integration, e2e — or all? (default: unit)
2. **Coverage target:** e.g., 70%, 80%, 90% (default: 80%)
3. **Priority areas:** Which modules, namespaces, packages, or files matter most?
   (If not specified, default to the largest or most depended-upon source files.)
4. **CI system:** GitHub Actions, GitLab CI, Azure Pipelines, none?
   (Used for coverage badge / workflow generation.)

---

## Phase 3 — Setup by Stack

### ── .NET (xUnit / NUnit / MSTest) ──

**Default framework: xUnit**

#### 3a. Create the test project

```powershell
# From solution root
dotnet new xunit -n {MainProjectName}.Tests -o {MainProjectName}.Tests
dotnet sln add {MainProjectName}.Tests/{MainProjectName}.Tests.csproj
dotnet add {MainProjectName}.Tests/{MainProjectName}.Tests.csproj reference {MainProjectName}/{MainProjectName}.csproj
```

#### 3b. Add standard packages

```powershell
cd {MainProjectName}.Tests
dotnet add package FluentAssertions
dotnet add package Moq
dotnet add package AutoFixture
dotnet add package AutoFixture.AutoMoq
dotnet add package coverlet.collector
```

#### 3c. Directory layout

```
{MainProjectName}.Tests/
  Fixtures/          # shared test fixtures / builders
  Unit/              # mirrors src namespace tree
    Services/
    Controllers/
  Integration/       # optional, if integration tests requested
  {MainProjectName}.Tests.csproj
```

#### 3d. Example unit test (xUnit + FluentAssertions + Moq)

For a service class `OrderService` with method `CalculateTotal`:

```csharp
// Unit/Services/OrderServiceTests.cs
using AutoFixture;
using AutoFixture.AutoMoq;
using FluentAssertions;
using Moq;
using Xunit;

namespace {MainProjectName}.Tests.Unit.Services;

public class OrderServiceTests
{
    private readonly IFixture _fixture = new Fixture().Customize(new AutoMoqCustomization());

    [Fact]
    public void CalculateTotal_WithValidItems_ReturnsCorrectSum()
    {
        // Arrange
        var items = _fixture.CreateMany<OrderItem>(3).ToList();
        var expectedTotal = items.Sum(i => i.Price * i.Quantity);
        var repoMock = _fixture.Freeze<Mock<IOrderRepository>>();
        var sut = _fixture.Create<OrderService>();

        // Act
        var result = sut.CalculateTotal(items);

        // Assert
        result.Should().Be(expectedTotal);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void CalculateTotal_WithInvalidQuantity_ThrowsArgumentException(int quantity)
    {
        // Arrange
        var items = new List<OrderItem> { new() { Price = 10m, Quantity = quantity } };
        var sut = _fixture.Create<OrderService>();

        // Act
        var act = () => sut.CalculateTotal(items);

        // Assert
        act.Should().Throw<ArgumentException>().WithMessage("*quantity*");
    }
}
```

#### 3e. Run with coverage

```powershell
dotnet test --collect:"XPlat Code Coverage" --results-directory ./TestResults

# Install report generator (once)
dotnet tool install -g dotnet-reportgenerator-globaltool

reportgenerator \
  -reports:"./TestResults/**/coverage.cobertura.xml" \
  -targetdir:"./TestResults/CoverageReport" \
  -reporttypes:Html
```

Open `TestResults/CoverageReport/index.html` to view the report.

---

### ── Python (pytest) ──

#### 3a. Directory layout

```
tests/
  conftest.py
  unit/
    __init__.py
    test_{module_name}.py
  integration/        # if requested
    __init__.py
  fixtures/
    __init__.py
```

#### 3b. Install dependencies

```powershell
pip install pytest pytest-cov pytest-mock pytest-asyncio
# Or with uv / poetry:
uv add --dev pytest pytest-cov pytest-mock pytest-asyncio
poetry add --group dev pytest pytest-cov pytest-mock pytest-asyncio
```

#### 3c. `pytest.ini` / `pyproject.toml` config

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--cov=src --cov-report=html --cov-report=term-missing --cov-fail-under=80"
asyncio_mode = "auto"

[tool.coverage.run]
source = ["src"]
omit = ["*/__init__.py", "*/migrations/*"]
```

#### 3d. `conftest.py`

```python
# tests/conftest.py
import pytest
from unittest.mock import MagicMock

# Example: shared DB fixture
@pytest.fixture(scope="session")
def db_session():
    """Provide an in-memory DB session for the test session."""
    from myapp.database import create_engine, SessionLocal
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = SessionLocal(bind=engine)
    yield session
    session.close()

# Example: mock external HTTP client
@pytest.fixture
def mock_http_client(mocker):
    return mocker.patch("myapp.clients.http_client.get")
```

#### 3e. Example unit test

For a function `calculate_discount(price, pct)`:

```python
# tests/unit/test_pricing.py
import pytest
from myapp.pricing import calculate_discount

class TestCalculateDiscount:
    def test_returns_discounted_price(self):
        # Arrange
        price, pct = 100.0, 20

        # Act
        result = calculate_discount(price, pct)

        # Assert
        assert result == 80.0

    @pytest.mark.parametrize("pct", [-1, 101])
    def test_raises_on_invalid_percentage(self, pct):
        with pytest.raises(ValueError, match="percentage"):
            calculate_discount(100.0, pct)

    def test_mocks_external_tax_service(self, mocker):
        mock_tax = mocker.patch("myapp.pricing.tax_service.get_rate", return_value=0.1)
        result = calculate_discount(100.0, 10)
        mock_tax.assert_called_once()
        assert result == pytest.approx(81.0)
```

#### 3f. Run

```powershell
pytest                                 # all tests + coverage
pytest tests/unit/ -v                  # unit only
pytest --cov=src --cov-report=html     # explicit coverage
```

HTML report at `htmlcov/index.html`.

---

### ── Node.js / TypeScript (Vitest preferred; Jest as fallback) ──

**Default: Vitest** (faster, native ESM, no config needed for Vite projects)

#### 3a. Install

```powershell
# Vitest
npm install -D vitest @vitest/coverage-v8 @testing-library/jest-dom

# Jest (if project uses CJS / older stack)
npm install -D jest ts-jest @types/jest
```

#### 3b. `vitest.config.ts`

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',       // or 'jsdom' for browser code
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      thresholds: { lines: 80, functions: 80, branches: 80 },
    },
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
  },
});
```

#### 3c. `jest.config.ts` (fallback)

```typescript
export default {
  preset: 'ts-jest',
  testEnvironment: 'node',
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
  coverageThreshold: { global: { lines: 80 } },
};
```

#### 3d. `package.json` scripts

```json
"scripts": {
  "test": "vitest run",
  "test:watch": "vitest",
  "test:coverage": "vitest run --coverage"
}
```

#### 3e. Example unit test (Vitest)

For `src/services/userService.ts`:

```typescript
// src/services/userService.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { UserService } from './userService';
import { UserRepository } from '../repositories/userRepository';

vi.mock('../repositories/userRepository');

describe('UserService', () => {
  let service: UserService;
  let repoMock: vi.Mocked<UserRepository>;

  beforeEach(() => {
    repoMock = new UserRepository() as vi.Mocked<UserRepository>;
    service = new UserService(repoMock);
  });

  describe('findById', () => {
    it('returns user when found', async () => {
      // Arrange
      const expected = { id: '1', name: 'Alice' };
      repoMock.findById.mockResolvedValue(expected);

      // Act
      const result = await service.findById('1');

      // Assert
      expect(result).toEqual(expected);
      expect(repoMock.findById).toHaveBeenCalledWith('1');
    });

    it('throws NotFoundError when user does not exist', async () => {
      repoMock.findById.mockResolvedValue(null);
      await expect(service.findById('missing')).rejects.toThrow('NotFoundError');
    });
  });
});
```

#### 3f. Run

```powershell
npm test                  # run all tests
npm run test:coverage     # with HTML report (coverage/index.html)
```

---

### ── Go ──

Go has a built-in test runner. No framework install required.

#### 3a. Add testify

```powershell
go get github.com/stretchr/testify/assert
go get github.com/stretchr/testify/require
go get github.com/stretchr/testify/mock
```

#### 3b. File placement

Test files live **beside** source files:

```
mypackage/
  order.go
  order_test.go        # unit tests for order.go
integration/
  order_integration_test.go   # build tag: //go:build integration
```

#### 3c. Example table-driven test

For `func CalculateTotal(items []Item) (float64, error)`:

```go
// order_test.go
package mypackage_test

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "mymodule/mypackage"
)

func TestCalculateTotal(t *testing.T) {
    tests := []struct {
        name    string
        items   []mypackage.Item
        want    float64
        wantErr bool
    }{
        {
            name:  "single item",
            items: []mypackage.Item{{Price: 10.0, Qty: 2}},
            want:  20.0,
        },
        {
            name:  "multiple items",
            items: []mypackage.Item{{Price: 5.0, Qty: 3}, {Price: 2.0, Qty: 4}},
            want:  23.0,
        },
        {
            name:    "negative quantity returns error",
            items:   []mypackage.Item{{Price: 10.0, Qty: -1}},
            wantErr: true,
        },
        {
            name:  "empty list returns zero",
            items: []mypackage.Item{},
            want:  0.0,
        },
    }

    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            got, err := mypackage.CalculateTotal(tc.items)
            if tc.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tc.want, got)
        })
    }
}
```

#### 3d. Mock example (testify/mock)

```go
type MockOrderRepo struct {
    mock.Mock
}

func (m *MockOrderRepo) FindByID(id string) (*Order, error) {
    args := m.Called(id)
    return args.Get(0).(*Order), args.Error(1)
}
```

#### 3e. Run

```powershell
go test ./...                          # all packages
go test ./... -cover                   # with coverage summary
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html   # HTML report
```

---

### ── Rust ──

#### 3a. Unit tests (same file)

```rust
// src/pricing.rs
pub fn calculate_discount(price: f64, pct: u8) -> Result<f64, String> {
    if pct > 100 {
        return Err(format!("percentage {} out of range", pct));
    }
    Ok(price * (1.0 - pct as f64 / 100.0))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn returns_discounted_price() {
        let result = calculate_discount(100.0, 20).unwrap();
        assert!((result - 80.0).abs() < f64::EPSILON);
    }

    #[test]
    fn returns_err_when_pct_exceeds_100() {
        let result = calculate_discount(100.0, 101);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("out of range"));
    }
}
```

#### 3b. Integration tests (`tests/` directory)

```rust
// tests/pricing_integration.rs
use mylib::pricing::calculate_discount;

#[test]
fn full_discount_gives_zero() {
    assert_eq!(calculate_discount(50.0, 100).unwrap(), 0.0);
}
```

#### 3c. `Cargo.toml` dev-dependencies

```toml
[dev-dependencies]
mockall = "0.13"
rstest = "0.23"       # parameterized tests
```

#### 3d. Run

```powershell
cargo test                             # all tests
cargo test -- --nocapture             # show println! output
cargo tarpaulin --out Html            # coverage (install: cargo install cargo-tarpaulin)
```

---

## Phase 4 — Generate Real Test Code for Key Functions

After setup, **inspect the actual source files** and generate real (non-stub) tests:

1. Identify the 3–5 most important source files (highest fan-in or business logic density).
2. For each file, enumerate its public functions/methods/classes.
3. For each, write at least:
   - 1 happy-path test
   - 1 edge-case or boundary test
   - 1 error / exception path test (if applicable)
4. Use **real values** from the codebase (actual class names, method signatures, types).
5. Wire up mocks for any injected dependency.

---

## Phase 5 — Test Patterns Checklist

Apply these patterns when writing tests:

| Pattern | Guidance |
|---|---|
| **Arrange-Act-Assert** | Clearly separate setup, execution, and verification with blank lines or comments |
| **Single assertion per concept** | One logical assertion per test (multiple `assert` calls are fine if they verify one thing) |
| **Dependency injection** | Prefer constructor injection; never `new` a dependency inside a method under test |
| **Mock only the boundary** | Mock I/O, HTTP, DB, clock, randomness — not pure business logic |
| **Test names as sentences** | `CalculateTotal_NegativeQuantity_ThrowsArgumentException` or `returns error when quantity is negative` |
| **No logic in tests** | No loops, conditionals, or string building — use parameterized/table tests instead |
| **Deterministic** | No `Thread.Sleep`, no real network/disk unless explicitly testing I/O |

---

## Phase 6 — Coverage Reporting

### HTML reports (summary)

| Stack | Command | Output path |
|---|---|---|
| .NET | `reportgenerator -reports:**/coverage.cobertura.xml -targetdir:CoverageReport -reporttypes:Html` | `CoverageReport/index.html` |
| Python | `pytest --cov=src --cov-report=html` | `htmlcov/index.html` |
| Node/TS | `npm run test:coverage` | `coverage/index.html` |
| Go | `go tool cover -html=coverage.out -o coverage.html` | `coverage.html` |
| Rust | `cargo tarpaulin --out Html` | `tarpaulin-report.html` |

### CI integration (GitHub Actions example)

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest   # or windows-latest for .NET heavy solutions
    steps:
      - uses: actions/checkout@v4

      # .NET
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.x' }
      - run: dotnet test --collect:"XPlat Code Coverage"

      # Python
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install pytest pytest-cov && pytest

      # Node
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci && npm run test:coverage

      # Go
      - uses: actions/setup-go@v5
        with: { go-version: '1.23' }
      - run: go test ./... -coverprofile=coverage.out

      # Rust
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo test
```

Adapt to the user's actual CI system if it differs (GitLab CI, Azure Pipelines, etc.).

---

## Phase 7 — Pre-commit Hooks

### cross-platform: `pre-commit` framework (recommended)

```powershell
pip install pre-commit
```

Create `.pre-commit-config.yaml` at repo root:

```yaml
repos:
  - repo: local
    hooks:
      # .NET
      - id: dotnet-test
        name: dotnet test
        language: system
        entry: dotnet test --no-build
        pass_filenames: false
        types: [file]
        files: \.cs$

      # Python
      - id: pytest
        name: pytest
        language: system
        entry: pytest tests/unit/ -q --no-header
        pass_filenames: false
        types: [python]

      # Node / TypeScript
      - id: vitest
        name: vitest
        language: system
        entry: npm test
        pass_filenames: false
        files: \.[jt]sx?$

      # Go
      - id: go-test
        name: go test
        language: system
        entry: go test ./...
        pass_filenames: false
        types: [go]

      # Rust
      - id: cargo-test
        name: cargo test
        language: system
        entry: cargo test
        pass_filenames: false
        types: [rust]
```

Keep **only the hook(s) matching the detected stack**.

```powershell
pre-commit install       # installs git hook
pre-commit run --all-files   # smoke test
```

---

## Completion Checklist

Before finishing, confirm:

- [ ] Test project / directory created
- [ ] Framework and supporting packages installed
- [ ] At least one real test file generated (not stubs)
- [ ] Coverage configured and threshold set
- [ ] HTML coverage report verified to generate
- [ ] CI workflow file added (if CI system was specified)
- [ ] Pre-commit hook installed
- [ ] `README.md` or `CONTRIBUTING.md` updated with "How to run tests" section (if those files exist)
