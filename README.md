# tesht -- Table-Driven Testing for Bash

![version](assets/version.svg) ![lines](assets/lines.svg) ![tests](assets/tests.svg) ![coverage](assets/coverage.svg)

**tesht** is a lightweight Bash testing framework that automatically discovers and runs test files and functions with formatted output and timing information. In addition to standard unit tests, tesht supports Go-inspired table-driven tests for efficient test code reuse.

![tesht output](assets/tesht.gif)
*tesht output*

--------------------------------------------------------------------------------------------

## Features

- Automatic discovery of test files ending in `_test.bash` and test functions starting with `test_`
- Output suppression and test isolation in separate subshells
- Per-test and suite-wide timing information
- Table-driven testing via `tesht.Run` for efficient test case reuse
- Built-in helpers for common testing needs:
  - HTTP server management (`tesht.StartHttpServer`)
  - Temporary directory creation (`tesht.MktempDir`)
  - Assertions (`tesht.AssertGot`, `tesht.AssertRC`)
  - Diff output formatting (`tesht.Diff`)
  - Logging (`tesht.Log`)

--------------------------------------------------------------------------------------------

## Usage

```bash
tesht [test_function]
```

- With **no arguments**, runs all `test_*` functions in `*_test.bash` files in the current directory
- With a **test function name**, runs only that function and subtests, if any

--------------------------------------------------------------------------------------------

## Basic Test Example

**echo_test.bash**:

```bash
# test_echo tests the behavior of the echo builtin.
test_echo() {
  ## act on the system under test
  got=$(echo hello)

  ## assert that the result was what we wanted
  tesht.AssertGot "$got" hello
}
```

Output:

```bash
$ tesht
--- PASS    8ms     test_echo
PASS        11ms
1/1
```

`tesht.AssertGot` compares `got` and `want`. If they differ, it shows their diff. The function's return code indicates whether the assertion passed, which becomes the test's overall result since it's the last command executed.

--------------------------------------------------------------------------------------------

## Writing Testable Code

Tesht is designed to test functions within a script, so first, ensure your code is organized into functions. Without functions, tesht won't be able to help.

Second, structure your script to allow function loading without execution. For example:

**greet**:

```bash
#!/usr/bin/env bash

greet() { echo "Hello, $1!"; }

return 2>/dev/null

read -p 'Your name: ' name
greet "$name"
```

The `return` statement after function definitions prevents script execution when sourced, while still allowing the functions to be tested. When run directly, the `return` statement errors (silently) and the script continues execution.

--------------------------------------------------------------------------------------------

## Table-Driven Tests

Table-driven tests reuse test logic across multiple cases. Here's an example:

**greet_test.bash**:

```bash
# test_greet tests that greet outputs a greeting message on stdout.
test_greet() {
  # Define test cases as associative arrays
  local -A case1=(
    [name]='greet Alice on stdout'
    [command]='greet Alice'
    [want]='Hello, Alice!'
  )
  local -A case2=(
    [name]='greet Bob on stdout'
    [command]='greet Bob'
    [want]='Hello, Bob!'
  )

  # Define a subtest that works with an individual case
  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"  # Convert case fields to local variables

    got=$(eval "$command")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run test_greet "${!case@}"
}
```

Output:

```bash
  --- PASS  12ms    test_greet/greet Alice
  --- PASS  11ms    test_greet/greet Bob
--- PASS    25ms    test_greet
PASS 29 ms
1/1
```

--------------------------------------------------------------------------------------------

## Public Functions

### tesht.Run
Runs a table-driven test with multiple cases:
```bash
tesht.Run test_name "${!case@}"
```

### tesht.Inherit
Converts associative array keys and values into local variables:
```bash
eval "$(tesht.Inherit casename)"
```

### tesht.AssertGot
Compares actual and expected output, showing a diff on failure:
```bash
tesht.AssertGot "$got" "$want"
```

### tesht.AssertRC
Checks if a return code matches the expected value:
```bash
tesht.AssertRC $rc $wantrc
```

### tesht.Diff
Shows a unified diff of actual and expected output, with tabs displayed as `^I`:
```bash
tesht.Diff "$got" "$want"
```

### tesht.Log
Outputs a message with newlines:
```bash
tesht.Log "Error message"
```

### tesht.MktempDir
Creates a temporary directory:
```bash
dir=$(tesht.MktempDir) || return 1
```

### tesht.StartHttpServer
Starts a local HTTP server on a specified port:
```bash
pid=$(tesht.StartHttpServer 8000) || return 1
```

--------------------------------------------------------------------------------------------

## License

MIT License. See LICENSE for full terms.