# tesht -- Table-Driven Testing for Bash

![version](assets/version.svg) ![lines](assets/lines.svg) ![tests](assets/tests.svg) ![coverage](assets/coverage.svg)

**tesht** is a lightweight Bash testing framework. It finds test files and functions
automatically and runs them with formatted output and timing information. In addition to the
usual solitary tests, tesht adds Go-inspired table-driven tests for effective test code
reuse.

![tesht output](assets/tesht.gif)
*tesht output*

--------------------------------------------------------------------------------------------

## Features

- Automatic discovery of test files ending in `_test.bash` and test functions starting with
  `test_`
- Output suppression
- Isolation of tests from one another since tests are run in separate subshells
- Time tracking and reporting per test and for the full suite
- Subtest support via `tesht.Run` for table-driven testing
- Helpers for dependencies such as an HTTP server or filesystem access

--------------------------------------------------------------------------------------------

## Usage

``` bash
tesht [test_function]
```

- With **no arguments**, it finds and runs all `test_*` functions in `*_test.bash` files in
    the current directory

- With a **test function name**, it finds and runs just that
    function (including subtests)

--------------------------------------------------------------------------------------------

## Basic Test Example

**echo_test.bash**:

``` bash
# test_echo tests the behavior of the echo builtin.
test_echo() {
  ## act on the system under test
  got=$(echo hello)

  ## assert that the result was what we wanted
  tesht.AssertGot "$got" hello
}
```

Output:

``` bash
$ tesht
--- PASS    8ms     test_echo
PASS        11ms
1/1
```

`tesht.AssertGot` compares `got` and `want`.  If they are unequal, it outputs a diff of the
two. Also, its return code reflects whether the assertion passed.  In our code here, that
becomes the return code of `test_echo` as well since `tesht.AssertGot` is the last command
called by the function. That means its return value is the return value of the test as a
whole.

--------------------------------------------------------------------------------------------

## Writing Testable Code

Scripts are written to be run, not tested.  Tesht is meant to test functions within a
script, not the script itself.

First, that means you need to have functions available to test.  If you are not writing
functions in your code, tesht won't do anything for you.

Second, that means we need a way to load functions from a script without actually running
it.

As an example, imagine we have a script with a function, `greet`, that greets a particular
name:

**greet**:

```bash
#!/usr/bin/env bash

greet() { echo "Hello, $1!"; }

read -p 'Your name: ' name
greet "$name"
```

**greet_test.bash**:

```bash
source ./greet

test_greet() {
  ...
}
```

The problem here is that we need to source the `greet` script to test it, however it runs
when it is sourced.  We just want to test the `greet` function, not run the `greet` script.

In order to prevent this, structure your script so that it can stop after functions are
defined but before the script executes them.

**greet**:

```bash
#!/usr/bin/env bash

greet() { echo "Hello, $1!"; }

return 2>/dev/null

read -p 'Your name: ' name
greet "$name"
```

Now the script's `greet` function can be tested.  We've added a `return` statement after the
function definitions and before the script starts using them.  When the script is sourced,
the sourcing ends at the return, leaving the functions defined but not running the rest of
the code.  By contrast, when the script is run from the command line, `return` doesn't make
sense and errors, and the script keeps going.  We swallow the error message with
`/dev/null`.

--------------------------------------------------------------------------------------------

## Table-Driven Tests

Table-driven tests reuse subtest logic across test cases.

Here is a test file with a test and two subtests.

**greet_test.bash**:

``` bash
# test_greet tests that greet outputs a greeting message on stdout.
test_greet() {
  # tesht.Run runs subtest (defined below) on each of these cases.
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

  # Define a subtest that works with an individual case.
  # Case values are turned into local variables with tesht.Inherit.
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit "$casename")"

    ## act
    got=$(eval "$command")  # this case's command is in $command because of tesht.Inherit

    ## assert
    tesht.AssertGot "$got" "$want"  # same for $want
  }

  tesht.Run test_greet "${!case@}"
}
```

Output:

``` bash
  --- PASS  12ms    test_greet/greet Alice
  --- PASS  11ms    test_greet/greet Bob
--- PASS    25ms    test_greet
PASS 29 ms
1/1
```

--------------------------------------------------------------------------------------------

## Helpers

### tesht.Inherit

Extracts the keys and values in an associative array into local variables named by key.
Useful for converting test case fields into variables you can work with.

``` bash
eval "$(tesht.Inherit casename)"
```

where `casename` is the name of the associative array variable.

### tesht.Diff

Outputs a unified diff of actual and expected output. Tabs in output are shown as `^I`.

`tesht.AssertGot` employs `tesht.Diff` internally to output an error message, but you may
find it useful for other purposes as well.

``` bash
if [[ $got != "$want" ]]; then
  tesht.Diff "$got" "$want"
  return 1
fi
```

--------------------------------------------------------------------------------------------

## License

MIT License. See LICENSE for full terms.
