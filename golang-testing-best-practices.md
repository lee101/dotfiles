# Go Testing Best Practices & Organization

## 1. Test File Organization

### Standard Structure
```
project/
├── cmd/
│   └── app/
│       ├── main.go
│       └── main_test.go
├── internal/
│   ├── handler/
│   │   ├── user.go
│   │   ├── user_test.go
│   │   └── user_integration_test.go
│   └── service/
│       ├── auth.go
│       ├── auth_test.go
│       └── testdata/
│           └── fixtures.json
├── pkg/
│   └── utils/
│       ├── helper.go
│       └── helper_test.go
└── test/
    ├── integration/
    │   └── api_test.go
    ├── e2e/
    │   └── workflow_test.go
    └── testdata/
        └── sample.json
```

## 2. Test Types & Naming Conventions

### Unit Tests
```go
// user_test.go - Same package for white-box testing
package user

func TestUser_Create(t *testing.T) {
    // Test implementation
}

func TestUser_Validate_EmptyName(t *testing.T) {
    // Descriptive sub-test naming
}
```

### Integration Tests
```go
// user_integration_test.go
//go:build integration
// +build integration

package user_test  // Black-box testing

func TestUserService_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }
    // Test with real dependencies
}
```

### Build Tags for Test Categories
```go
//go:build unit
// +build unit

//go:build integration && !short
// +build integration,!short

//go:build e2e
// +build e2e
```

## 3. Table-Driven Tests

```go
func TestCalculate(t *testing.T) {
    tests := []struct {
        name     string
        input    int
        expected int
        wantErr  bool
    }{
        {
            name:     "positive number",
            input:    5,
            expected: 10,
            wantErr:  false,
        },
        {
            name:     "zero",
            input:    0,
            expected: 0,
            wantErr:  false,
        },
        {
            name:     "negative number",
            input:    -1,
            expected: 0,
            wantErr:  true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Calculate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Calculate() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if got != tt.expected {
                t.Errorf("Calculate() = %v, want %v", got, tt.expected)
            }
        })
    }
}
```

## 4. Test Helpers & Fixtures

### Helper Functions
```go
// test_helpers.go
package user_test

func setupTestDB(t *testing.T) (*sql.DB, func()) {
    t.Helper()
    
    db := createTempDB()
    cleanup := func() {
        db.Close()
        removeTempDB()
    }
    
    return db, cleanup
}

func TestUserRepository(t *testing.T) {
    db, cleanup := setupTestDB(t)
    defer cleanup()
    
    // Use db for testing
}
```

### Golden Files
```go
func TestGenerateReport(t *testing.T) {
    got := GenerateReport(data)
    
    golden := filepath.Join("testdata", "report.golden")
    if *update {
        os.WriteFile(golden, got, 0644)
    }
    
    want, _ := os.ReadFile(golden)
    if !bytes.Equal(got, want) {
        t.Errorf("Report mismatch")
    }
}
```

## 5. Mocking & Interfaces

### Interface-Based Mocking
```go
// service.go
type UserRepository interface {
    GetUser(id string) (*User, error)
    SaveUser(user *User) error
}

// service_test.go
type mockUserRepo struct {
    getUserFunc func(string) (*User, error)
}

func (m *mockUserRepo) GetUser(id string) (*User, error) {
    return m.getUserFunc(id)
}

func TestUserService(t *testing.T) {
    mock := &mockUserRepo{
        getUserFunc: func(id string) (*User, error) {
            return &User{ID: id, Name: "Test"}, nil
        },
    }
    
    service := NewUserService(mock)
    // Test service
}
```

### Using testify/mock
```go
import "github.com/stretchr/testify/mock"

type MockRepository struct {
    mock.Mock
}

func (m *MockRepository) GetUser(id string) (*User, error) {
    args := m.Called(id)
    return args.Get(0).(*User), args.Error(1)
}
```

## 6. Testing Commands & Tools

### Running Tests
```bash
# Run all tests
go test ./...

# Run with coverage
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Run specific test
go test -run TestUserCreate ./internal/user

# Run with race detector
go test -race ./...

# Run with verbose output
go test -v ./...

# Run only unit tests (using build tags)
go test -tags=unit ./...

# Run integration tests
go test -tags=integration ./...

# Skip long tests
go test -short ./...

# Parallel execution
go test -parallel 4 ./...

# Benchmark tests
go test -bench=. -benchmem ./...
```

## 7. Test Organization Best Practices

### Package Structure
- Keep `_test.go` files next to source files
- Use `package foo_test` for black-box testing
- Use `package foo` for white-box testing when needed
- Create `testdata/` directories for test fixtures

### Subtests & Test Suites
```go
func TestUserOperations(t *testing.T) {
    t.Run("Create", func(t *testing.T) {
        t.Parallel()
        // Test create
    })
    
    t.Run("Update", func(t *testing.T) {
        t.Parallel()
        // Test update
    })
    
    t.Run("Delete", func(t *testing.T) {
        // Test delete
    })
}
```

### Test Setup & Teardown
```go
func TestMain(m *testing.M) {
    // Setup before tests
    setupTestEnvironment()
    
    // Run tests
    code := m.Run()
    
    // Cleanup after tests
    teardownTestEnvironment()
    
    os.Exit(code)
}
```

## 8. Testing HTTP Handlers

```go
func TestHandler(t *testing.T) {
    req := httptest.NewRequest("GET", "/users/123", nil)
    w := httptest.NewRecorder()
    
    handler := http.HandlerFunc(GetUserHandler)
    handler.ServeHTTP(w, req)
    
    resp := w.Result()
    if resp.StatusCode != http.StatusOK {
        t.Errorf("expected status 200, got %d", resp.StatusCode)
    }
}
```

## 9. Testing with Context

```go
func TestWithTimeout(t *testing.T) {
    ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
    defer cancel()
    
    err := SlowOperation(ctx)
    if err != context.DeadlineExceeded {
        t.Errorf("expected timeout error, got %v", err)
    }
}
```

## 10. Common Testing Patterns

### Cleanup with t.Cleanup()
```go
func TestWithCleanup(t *testing.T) {
    resource := acquireResource()
    t.Cleanup(func() {
        resource.Close()
    })
    
    // Use resource
}
```

### Parallel Tests
```go
func TestParallel(t *testing.T) {
    t.Parallel() // Mark test as safe for parallel execution
    
    // Test implementation
}
```

### Skip Tests Conditionally
```go
func TestRequiresDocker(t *testing.T) {
    if !dockerAvailable() {
        t.Skip("Docker not available")
    }
    
    // Test with Docker
}
```

## 11. CI/CD Integration

### Makefile Example
```makefile
.PHONY: test test-unit test-integration test-e2e coverage

test:
	go test -v -race ./...

test-unit:
	go test -v -short -tags=unit ./...

test-integration:
	go test -v -tags=integration ./...

test-e2e:
	go test -v -tags=e2e ./test/e2e/...

coverage:
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint:
	golangci-lint run

bench:
	go test -bench=. -benchmem ./...
```

### GitHub Actions Example
```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-go@v4
      with:
        go-version: '1.21'
    
    - name: Run tests
      run: |
        go test -v -race -coverprofile=coverage.out ./...
        go tool cover -func=coverage.out
    
    - name: Run linters
      run: golangci-lint run
```

## 12. Testing Tools & Libraries

### Essential Testing Libraries
- **testify**: Assertions and mocks
- **gomock**: Google's mocking framework
- **ginkgo/gomega**: BDD-style testing
- **httptest**: Testing HTTP handlers
- **goleak**: Goroutine leak detection
- **go-cmp**: Deep equality comparisons

### Code Quality Tools
- **golangci-lint**: Meta linter
- **go test -race**: Race condition detector
- **go vet**: Static analysis
- **staticcheck**: Advanced static analysis
- **gosec**: Security checker

## 13. Performance & Benchmark Testing

```go
func BenchmarkFunction(b *testing.B) {
    // Setup
    data := prepareData()
    
    b.ResetTimer() // Reset timer after setup
    
    for i := 0; i < b.N; i++ {
        ProcessData(data)
    }
}

func BenchmarkParallel(b *testing.B) {
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            ProcessData()
        }
    })
}
```

## 14. Test Coverage Goals

- Aim for 70-80% coverage minimum
- Focus on critical business logic
- Don't test generated code
- Exclude vendor directories
- Test error paths thoroughly

## Quick Reference Commands

```bash
# Generate mocks with mockgen
mockgen -source=interface.go -destination=mocks/mock.go

# Check for unchecked errors
errcheck ./...

# Detect goroutine leaks
go test -run TestLeak -leak ./...

# Profile tests
go test -cpuprofile=cpu.prof -memprofile=mem.prof ./...
go tool pprof cpu.prof

# Mutation testing
go-mutesting ./...
```