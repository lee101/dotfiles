# Go Test Coverage Improvement Guide

## Quick Coverage Commands

```bash
# Check current coverage
go test -cover ./...

# Generate detailed coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html

# See coverage by function
go tool cover -func=coverage.out

# Coverage with specific packages
go test -coverpkg=./pkg/...,./internal/... -coverprofile=coverage.out ./...

# Coverage excluding generated files
go test -coverprofile=coverage.out $(go list ./... | grep -v /mocks)
```

## 1. Find Uncovered Code

### Visual Coverage Analysis
```bash
# Generate HTML report and open in browser
go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out

# Terminal-based coverage summary
go tool cover -func=coverage.out | grep -v "100.0%"

# Sort by coverage percentage
go tool cover -func=coverage.out | sort -k3 -n
```

### Coverage Script
```bash
#!/bin/bash
# save as check-coverage.sh

THRESHOLD=80
COVERAGE=$(go test -cover ./... 2>&1 | grep -oE '[0-9]+\.[0-9]+%' | sed 's/%//' | awk '{s+=$1; c++} END {print s/c}')

echo "Overall coverage: ${COVERAGE}%"

if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
    echo "❌ Coverage below threshold ($THRESHOLD%)"
    exit 1
else
    echo "✅ Coverage meets threshold"
fi
```

## 2. Systematic Coverage Improvement

### Priority Order for Testing
1. **Error paths** - Often missed but critical
2. **Edge cases** - Boundary conditions
3. **Main business logic** - Core functionality
4. **Utility functions** - Shared code
5. **Simple getters/setters** - Low priority

### Example: Testing Error Paths
```go
// Original function
func ProcessUser(id string) (*User, error) {
    if id == "" {
        return nil, errors.New("empty ID")
    }
    
    user, err := db.GetUser(id)
    if err != nil {
        return nil, fmt.Errorf("failed to get user: %w", err)
    }
    
    if !user.IsActive {
        return nil, errors.New("user is inactive")
    }
    
    return user, nil
}

// Complete test coverage
func TestProcessUser(t *testing.T) {
    tests := []struct {
        name    string
        id      string
        dbUser  *User
        dbErr   error
        wantErr string
    }{
        {
            name:    "empty ID",
            id:      "",
            wantErr: "empty ID",
        },
        {
            name:    "database error",
            id:      "123",
            dbErr:   errors.New("connection failed"),
            wantErr: "failed to get user",
        },
        {
            name:    "inactive user",
            id:      "123",
            dbUser:  &User{ID: "123", IsActive: false},
            wantErr: "user is inactive",
        },
        {
            name:    "success",
            id:      "123",
            dbUser:  &User{ID: "123", IsActive: true},
            wantErr: "",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Mock setup here
            _, err := ProcessUser(tt.id)
            
            if tt.wantErr != "" {
                require.Error(t, err)
                assert.Contains(t, err.Error(), tt.wantErr)
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

## 3. Coverage for Different Code Patterns

### Testing Interfaces
```go
// coverage_helper_test.go
func TestAllInterfaceMethods(t *testing.T) {
    var _ UserService = (*MockUserService)(nil) // Compile-time check
    
    mock := &MockUserService{}
    
    // Test each interface method
    methods := []struct {
        name string
        test func()
    }{
        {"Create", func() { mock.Create(context.TODO(), &User{}) }},
        {"Update", func() { mock.Update(context.TODO(), &User{}) }},
        {"Delete", func() { mock.Delete(context.TODO(), "id") }},
        {"Get", func() { mock.Get(context.TODO(), "id") }},
    }
    
    for _, m := range methods {
        t.Run(m.name, m.test)
    }
}
```

### Testing Panic Recovery
```go
func TestPanicRecovery(t *testing.T) {
    defer func() {
        if r := recover(); r == nil {
            t.Error("expected panic")
        }
    }()
    
    FunctionThatShouldPanic(nil)
}
```

### Testing Goroutines
```go
func TestConcurrentOperations(t *testing.T) {
    var wg sync.WaitGroup
    errors := make(chan error, 10)
    
    for i := 0; i < 10; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            if err := ConcurrentOperation(id); err != nil {
                errors <- err
            }
        }(i)
    }
    
    wg.Wait()
    close(errors)
    
    for err := range errors {
        t.Errorf("concurrent operation failed: %v", err)
    }
}
```

## 4. Automated Coverage Tools

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running tests with coverage check..."

COVERAGE=$(go test -cover ./... 2>&1 | grep -oE 'coverage: [0-9]+\.[0-9]+%' | awk '{print $2}' | sed 's/%//' | awk '{s+=$1; c++} END {print s/c}')
THRESHOLD=75

if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
    echo "❌ Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
    echo "Run 'go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out' to see uncovered code"
    exit 1
fi

echo "✅ Coverage ${COVERAGE}% meets threshold"
```

### Makefile Targets
```makefile
.PHONY: coverage coverage-report coverage-check coverage-diff

COVERAGE_THRESHOLD := 80

coverage:
	@go test -v -race -coverprofile=coverage.out ./...
	@go tool cover -func=coverage.out

coverage-report:
	@go test -v -race -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Opening coverage report..."
	@open coverage.html || xdg-open coverage.html

coverage-check:
	@echo "Checking coverage threshold ($(COVERAGE_THRESHOLD)%)..."
	@go test -coverprofile=coverage.out ./... > /dev/null 2>&1
	@coverage=$$(go tool cover -func=coverage.out | grep total | awk '{print $$3}' | sed 's/%//'); \
	if [ $$(echo "$$coverage < $(COVERAGE_THRESHOLD)" | bc) -eq 1 ]; then \
		echo "❌ Coverage $$coverage% is below threshold $(COVERAGE_THRESHOLD)%"; \
		exit 1; \
	else \
		echo "✅ Coverage $$coverage% meets threshold"; \
	fi

coverage-diff:
	@echo "Comparing coverage with main branch..."
	@git stash
	@go test -coverprofile=coverage-new.out ./...
	@git checkout main
	@go test -coverprofile=coverage-main.out ./...
	@git checkout -
	@git stash pop
	@go tool cover -func=coverage-main.out > coverage-main.txt
	@go tool cover -func=coverage-new.out > coverage-new.txt
	@diff coverage-main.txt coverage-new.txt || true
```

## 5. CI/CD Coverage Integration

### GitHub Actions with Coverage
```yaml
name: Test Coverage

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - uses: actions/setup-go@v4
      with:
        go-version: '1.21'
    
    - name: Run tests with coverage
      run: go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
    
    - name: Check coverage threshold
      run: |
        COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
        echo "Coverage: ${COVERAGE}%"
        if (( $(echo "$COVERAGE < 80" | bc -l) )); then
          echo "Coverage below 80% threshold"
          exit 1
        fi
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.out
    
    - name: Generate coverage badge
      run: |
        COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}')
        echo "COVERAGE=${COVERAGE}" >> $GITHUB_ENV
    
    - name: Comment PR with coverage
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: `📊 Test Coverage: ${process.env.COVERAGE}`
          })
```

## 6. Quick Coverage Wins

### Test Generated Code Patterns
```go
// Test all enum values
func TestStatusString(t *testing.T) {
    statuses := []Status{
        StatusPending,
        StatusActive,
        StatusInactive,
        StatusDeleted,
    }
    
    for _, s := range statuses {
        got := s.String()
        assert.NotEmpty(t, got)
    }
}

// Test all error types
func TestErrorTypes(t *testing.T) {
    errors := []error{
        ErrNotFound,
        ErrUnauthorized,
        ErrInvalidInput,
    }
    
    for _, err := range errors {
        assert.Error(t, err)
        assert.NotEmpty(t, err.Error())
    }
}
```

### Test Struct Methods
```go
// Test all getters/setters
func TestUserMethods(t *testing.T) {
    u := &User{}
    
    // Test setters
    u.SetName("John")
    u.SetAge(30)
    u.SetEmail("john@example.com")
    
    // Test getters
    assert.Equal(t, "John", u.GetName())
    assert.Equal(t, 30, u.GetAge())
    assert.Equal(t, "john@example.com", u.GetEmail())
    
    // Test validation
    assert.NoError(t, u.Validate())
    
    // Test JSON marshaling
    data, err := json.Marshal(u)
    assert.NoError(t, err)
    assert.NotEmpty(t, data)
}
```

## 7. Coverage Exclusions

### Exclude from Coverage
```go
// Exclude generated files
//go:generate mockgen -source=interface.go -destination=mocks/mock.go

// Exclude main function (if minimal)
func main() {
    // coverageignore
    app.Run()
}

// Build tags to exclude
//go:build !test
// +build !test
```

### .coveragerc Configuration
```ini
[run]
omit = 
    */mocks/*
    */generated/*
    */vendor/*
    */test/*
    *_test.go

[report]
exclude_lines =
    panic\(
    // coverageignore
    ^// \+build
    if __name__ == .__main__.:
```

## 8. Coverage Analysis Tools

```bash
# Install useful tools
go install github.com/jandelgado/gcov2lcov@latest
go install github.com/axw/gocov/gocov@latest
go install github.com/AlekSi/gocov-xml@latest

# Convert to different formats
gocov convert coverage.out | gocov-xml > coverage.xml
gcov2lcov -infile=coverage.out -outfile=coverage.lcov

# Detailed analysis
gocov convert coverage.out | gocov report

# Find specific uncovered lines
go tool cover -func=coverage.out | grep -E "0.0%|[0-4][0-9]\..*%"
```

## Quick Reference

```bash
# One-liner to find files with low coverage
go test -coverprofile=c.out ./... && go tool cover -func=c.out | sort -k3 -n | head -20

# Coverage for specific function
go test -coverprofile=c.out -run TestSpecific ./pkg/... && go tool cover -func=c.out | grep FunctionName

# Coverage delta between branches
git diff main --name-only | grep "\.go$" | xargs -I {} go test -cover $(dirname {})

# Parallel coverage generation
find . -type d -name "*" | xargs -P 4 -I {} go test -cover {}
```

## Coverage Improvement Checklist

- [ ] Run initial coverage report
- [ ] Identify packages < 70% coverage
- [ ] Prioritize critical business logic
- [ ] Add tests for all error paths
- [ ] Test edge cases and boundaries
- [ ] Add table-driven tests
- [ ] Test concurrent operations
- [ ] Set up CI coverage checks
- [ ] Add coverage badges to README
- [ ] Configure coverage trends tracking