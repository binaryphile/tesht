# tesht — Table-Driven Testing for Bash

**tesht** is a lightweight testing framework for Bash scripts, following familiar patterns
from Go’s testing package. It allows you to write clean, maintainable, and table-driven
tests for your shell functions.

--------------------------------------------------------------------------------------------

## Overview

- Designed for testing Bash functions directly in script files
- Follows Go-style test conventions for structure and naming
- Test files are named to match the scripts they validate (e.g., `foo.bash` →
  `foo_test.bash`)
- Test functions are discovered by name (e.g., `test_FooDoesBar`)
- `tesht` runs all tests in the current directory or only a specific function if requested

--------------------------------------------------------------------------------------------

## Features

- **Automatic test discovery**: Finds and runs all `test_*` functions
- **Isolation**: Each test runs in its own subshell
- **Detailed results**: Displays per-test and suite-wide pass/fail status with timing
- **Table-driven testing**: Define reusable test logic and data tables
- **Assertions**:
  - `tesht.AssertGot` — assert output matches expected
  - `tesht.AssertRC` — assert return code matches expected
- **Runtime utilities**:
  - `tesht.StartHttpServer` — serve files via HTTP during tests
  - `tesht.MktempDir` — safely create and clean up temporary directories

--------------------------------------------------------------------------------------------

## Installation

Place `tesht` in a directory on your `$PATH`. You can copy or symlink it:

``` bash
cp tesht /usr/local/bin/
# or
ln -s "$PWD/tesht" ~/bin/
```

--------------------------------------------------------------------------------------------

## Usage

``` bash
tesht [test_function]
```

- No arguments: runs all `test_*` functions in all `*_test.bash` files
- With a function name: runs only the named test and its subtests

--------------------------------------------------------------------------------------------

## Example

``` bash
test_SayHello() {
  got=$(SayHello "Alice")
  tesht.AssertGot "Hello, Alice!" "$got"
}
```

--------------------------------------------------------------------------------------------

## Writing Testable Code

To make code testable:

- Organize logic into functions
- Prevent execution on load with:

``` bash
return 2>/dev/null
```

This allows sourcing the script in tests without running it.

--------------------------------------------------------------------------------------------

## Table-Driven Tests

Table-driven tests allow multiple cases to share logic:

``` bash
test_GreetTable() {
  local cases=(
    ['Hello']="SayHello Alice => Hello, Alice!"
    ['Hi']="SayHi Bob => Hi, Bob!"
  )

  for name in "${!cases[@]}"; do
    tesht.Run "$name" "${cases[$name]}" runCase
  done
}

runCase() {
  tesht.Inherit "$@"
  # use inherited vars: $1 = function call, $2 = expected
  local got
  got=$(eval "${1}")
  tesht.AssertGot "$2" "$got"
}
```

Subtests will be shown with timing and results.

--------------------------------------------------------------------------------------------

## Public Functions

- `tesht.Run name args... func` — Run a subtest with name and arguments
- `tesht.Inherit args...` — Load named values into local variables
- `tesht.AssertGot expected actual` — Compare output
- `tesht.AssertRC expected actual` — Compare return codes
- `tesht.Diff expected actual` — Show unified diff on mismatch
- `tesht.Log message...` — Print a message from a test
- `tesht.MktempDir` — Create and track a temporary directory
- `tesht.StartHttpServer dir [port]` — Serve a directory over HTTP for tests

--------------------------------------------------------------------------------------------

## License

MIT License


---


- Overview
  - framework for testing Bash functions in scripts
  - follows patterns from Go testing
  - test files are named based on the file they test
  - tests are functions with special names
  - 
- Features
  - Auto-discovery of `_test.bash` files & `test_` functions
  - Output suppression & test isolation (subshells)
  - Per-test & suite-wide timing
  - Table-driven testing via `tesht.Run`
  - Built-in helpers
    - HTTP server management (`tesht.StartHttpServer`)
    - Temp directory creation (`tesht.MktempDir`)
    - Assertions (`tesht.AssertGot`, `tesht.AssertRC`)
    - Diff output formatting (`tesht.Diff`)
    - Logging (`tesht.Log`)
- Installation
- Usage
  - `tesht [test_function]`
    - No arguments: runs all `test_*` in `*_test.bash`
    - With function name: runs only that function & subtests
- Example
   - Uses `tesht.AssertGot`
   - Output: PASS/FAIL with timing
- Writing Testable Code
  - Organize code into functions
  - Structure script for function loading without execution
    - Use `return 2>/dev/null` after function definitions
- Table-Driven Tests
  - Reuse test logic across cases
  - Example: `greet_test.bash`
    - Define cases as associative arrays
    - Use `tesht.Inherit` and `tesht.Run`
    - Output: subtest results with timing
- Public Functions
  - tesht.Run: run table-driven tests
  - tesht.Inherit: convert array keys/values to locals
  - tesht.AssertGot: compare actual/expected output
  - tesht.AssertRC: check return code
  - tesht.Diff: show unified diff
  - tesht.Log: output message
  - tesht.MktempDir: create temp dir
  - tesht.StartHttpServer: start HTTP server
- License
  - MIT License
