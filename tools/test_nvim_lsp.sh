#!/bin/bash

echo "Testing Neovim TypeScript LSP configuration..."

# Kill any existing TypeScript processes
echo "Cleaning up existing TypeScript servers..."
pkill -f typescript-language-server 2>/dev/null
pkill -f tsserver 2>/dev/null
sleep 1

# Test file
TEST_FILE="/tmp/test_ts.ts"

# Create test file
cat > "$TEST_FILE" << 'EOF'
console.log("Testing TypeScript LSP");

const greeting: string = "Hello TypeScript";
const count: number = 42;

interface User {
  name: string;
  age: number;
  email?: string;
}

function greetUser(user: User): string {
  return `Hello, ${user.name}! You are ${user.age} years old.`;
}

const testUser: User = {
  name: "Test",
  age: 25
};

console.log(greetUser(testUser));

// Test type error (uncomment to test diagnostics)
// const wrong: string = 123;
EOF

echo "Opening test file in Neovim..."
echo "Commands to test:"
echo "  :LspInfo      - Check if TypeScript LSP is running"
echo "  :LspStats     - Show custom LSP stats"
echo "  :LspStopIdle  - Stop idle LSP servers"
echo "  :LspRestart typescript - Restart TypeScript LSP"
echo ""
echo "The LSP should:"
echo "  - Use only ONE tsserver process (not two)"
echo "  - Be limited to 2GB memory"
echo "  - Auto-shutdown after 5 minutes of inactivity"
echo ""

# Open in Neovim
nvim "$TEST_FILE" -c "echo 'TypeScript LSP test ready. Use :LspInfo to check status.'"