# tesht - table-driven testing for Bash

**tesht** is a command-line tool for testing Bash code.  By itself, the command `tesht`
searches for files in the current directory ending in `_test.bash`.  It runs any test
functions it finds, functions having names starting with `test_`.  Each function and its
success or failure is then reported in a succinct format, along with timing measurements.
Test output is suppressed unless the test failed, in which case the test output is shown as
well.

## Features

- simple naming conventions - e.g. `test_myfunc()` in `myfunc_test.bash`
- output suppression - only see function output when tests fail
- reporting - individual and overall test results and timing

## Usage

```bash
tesht [DIR]

DIR is a directory containing test files.
```

## Example

Tests should typically follow the triple-A pattern of [Arrange, Act, Assert]:

[Arrange, Act, Assert]: https://automationpanda.com/2020/07/07/arrange-act-assert-a-pattern-for-writing-good-tests/

- *arrange* the necessary test dependencies, such as a temporary directory as a workspace
- *act* with the system-under-test, i.e. the function we are testing
- *assert* what the resulting state of affairs should be and flag the differences

The following test function could appear in a file named `ln_test.bash`:

```bash
# test_ln tests the shell's `ln` symlink command.
# A temporary directory is created as a workspace and is removed afterward.
# The test makes a symlink in the workspace with `ln -sf`.
test_ln() {
  ## arrange

  # make the temporary directory and change to it as working directory
  dir=$(mktemp -d /tmp/tesht.XXXXXX)                # mktemp finds a safe name and makes the directory
  [[ $dir == /tmp/tesht.* ]] || {                   # ensure we got a valid name
    echo "ln fatal: couldn't make temp directory"   # dependency setup errors are fatal
    return 1
  }
  trap "rm -rf $dir" EXIT   # always clean up
  cd $dir

  ## act

  # Run the command and capture the output in got and result code in rc.
  # In this case, we are linking to the non-existent target.txt.
  # We're using -f which means that's ok and link.txt should get made.
  got=$(ln -sf target.txt link.txt 2>&1)
  rc=$?

  ## assert

  # assert no error
  [[ $rc == 0 ]] || {
    echo -e "ln: error = $rc, want: 0\n$got"
    return 1
  }

  # assert that the symlink was made
  [[ -L link.txt ]] || {
    echo -e "ln: expected link.txt to be symlink\n$got"
    return 1
  }
}
```

Some things to notice:

- the filename and function name follow the required naming convention
- the workspace directory, a dependency of the test, is created in the "arrange" section
- it is cleaned up by a trap, which is a deferred event triggered when the test completes
- output suppression is handled by the test -- `got` captures output
- assertions are normal Bash tests that output a message on error and return 1
- `got` is shown by the error branches of assertions

If this test passes, the `ln` command returned success and the link existed, because the
assertions would have failed otherwise.

Now run the command `tesht` in the same folder as `ln_test.bash`:

```bash
$ tesht
=== RUN   test_ln
--- PASS: test_ln (12 ms)
PASS (21 ms)
```

This shows us when the test starts and finishes, with timing.  The final PASS applies to the
entire test suite.

Had the `ln` command errored, it would look like this:

```bash
=== RUN   test_ln
ln: error = 1, want: 0

--- FAIL: test_ln (9 ms)
FAIL (18 ms)
```

This follows the same order of events as the successful test, this time the assertion
triggers its error message, and the overall result is now FAIL.  *Any* individual test
failure also fails the suite, although it won't stop further tests from also being run.

## Table-driven tests

`test_ln` is a self-contained test that takes no arguments, which works well for a one-shot
test.  However, sometimes you need variations on a test -- a different parameter such
as a filename, but the rest of the process the same as the original test.  The table-driven
approach can help in this case.

Table tests are just another way of saying "parameterized tests".  Table tests are the same
test as the one-shot version except they accept arguments and they get a little help from
tesht.

Quoting from the [Go wiki]:

[Go wiki]: https://go.dev/wiki/TableDrivenTests

> Writing good tests is not trivial, but in many situations a lot of ground can be covered
> with table-driven tests: Each table entry is a complete test case with inputs and expected
> results, and sometimes with additional information such as a test name to make the test
> output easily readable. If you ever find yourself using copy and paste when writing a
> test, think about whether refactoring into a table-driven test or pulling the copied code
> out into a helper function might be a better option.
>
> Given a table of test cases, the actual test simply iterates through all table entries and
> for each entry performs the necessary tests. The test code is written once and amortized
> over all table entries, so it makes sense to write a careful test with good error
> messages.

A table-driven test begins as a regular test function, following the usual naming convention.
However, rather than arrange, act and assert, the test function instead defines test cases
and a subtest (a function) that expects to receive one of test case at a time.

- the test declares test cases as maps (associative arrays) with the subtest's required
  paramaters
- the test defines the subtest function
- the test loops over the test cases, feeding them to the subtest as arguments

The subtest performs the usual arrange, act and assert pattern.  This requires minor support
from tesht, in the form of the `t.run` function (the `t.` is for `tesht`).  `t.run` runs the
subtest, handling report formatting and timing.  Its signature is:

```bash
t.run subtest testcasename
```

where `subtest` is the name of the subtest function (usually just `subtest`) and
`testcasename` is the name of the associative array containing the test case.

### Table-driven test example

Let's expand the `test_ln` to a table-driven test by adding a test case.  This case will
address what should happen if the command fails with an error.  For example, `ln -sf` does
and should fail if the directory of the link is not writable.

Before looking at the test, there are a couple of things to know:

- test cases are maps (associative arrays) defined with `local -A`
- test cases require the "name" key to display in the results

Other parameters are free-form.  Test cases are not even required to all contain the same
keys; it just depends on how the subtest is written.

Let's look at the test before the subtest has been fully defined:

```bash
# Now, table-driven!
test_ln() {
  local -A testcase1=(
    [name]="create a link"
    [dir]='$(mktemp -d /tmp/tesht.XXXXXX)'
  )

  local -A testcase2=(
    [name]="fail when the link's directory is not writable"
    [wanterr]=1
  )

  # define subtest -- subtest runs each test case
  subtest() {
    # TBD
  }

  # loop through the test cases
  failed=0
  for testcasename in testcase{1,2}; do
    t.run subtest $testmapname || failed=1
  done

  return $failed
}
```

Here the two test case maps form the "table".  Notice that the two test cases are not
defined the same way.  The link creation test case only specifies a workspace directory,
while the failure test only specifies `wanterr`.  When writing a failure test, it is typical
to use `wanterr` to specify the result code we expect.  The subtest is written so that the
presence of `wanterr` tells it not to test as if the command had succeeded but instead to
only look at the error result.

To create the subtest, we're going to create a function that takes the name of a test case
map.  The keys of that map are the test case parameters, which we are going to finesse into
regular variables so that the test is easier to read.  `$dir` is easier to read and write
than `${testcase[dir]}`.  The test helper `t.inherit` creates a string containing
declarations that create variables from the keys in a map so we can write clearer
expressions.  We create them by `eval`ing the result.

We create the directory with `mktemp`, and don't want to create the directory until the test
is actually running, so we can't evaluate mktemp in the map declaration -- it has to wait.
So we delay the expansion with `mktemp` by quoting it in the map and then eval'ing that
value when the subtest detects its presence with a `-v` variable existence test.

Here's the test, now with the subtest:

```bash
test_ln() {
  local -A testcase1=(
    [name]="create a link"
  )

  local -A testcase2=(
    [name]="fail when the link's directory is not writable"
    [wanterr]=1
  )

  # define subtest -- subtest runs each test case
  subtest() {
    testcase=$1
    eval "$(t.inherit $testcase)"   # now testcase keys are variables

    ## arrange

    # temporary directory
    dir=$(mktemp -d /tmp/tesh.XXXXXX)
    [[ $dir == /tmp/tesht.* ]] || {                   # ensure we got a valid name
      echo "ln fatal: couldn't make temp directory"   # dependency setup errors are fatal
      return 1
    }
    trap "rm -rf $dir" EXIT   # always clean up
    cd $dir

    ## act

    got=$(ln -sf target.txt link.txt 2>&1)
    rc=$?

    ## assert

    # check for error-wanted cases first
    [[ -v wanterr ]] && {
      [[ $rc == $wanterr ]] && return  # great!
      echo -e "    ln/$name error = $rc, want: $wanterr\n$got"
      return 1
    }

    # assert no error
    [[ $rc == 0 ]] || {
      echo -e "    ln/$name error = $rc, want: 0\n$got"
      return 1
    }

    # assert that the symlink was made
    [[ -L link.txt ]] || {
      echo -e "    ln/$name expected link.txt to be symlink\n$got"
      return 1
    }
  }

  # loop through the test cases
  failed=0
  for testcasename in testcase{1,2}; do
    t.run subtest $testmapname || failed=1
  done

  return $failed
}
```

The subtest looks an awful lot like the original test, with a couple differences.  First,
there's the bit about expanding map keys into variables.  Also there is the branch to handle
the kind of test cases that want error codes (`[[ -v wanterr ]]`).

With that branch, we return success so long as the error code is the one we wanted.
Otherwise, we fail the subtest like a normal assertion.  Note that the output now includes
the subtest name and is indented to match tesht's report format.

## `t.diff`

tesht offers a few functions as we've seen.  `t.diff` is a helper function to show
differences in command output vs what was expected.  It also makes some special characters
like tab visible.  The output is from the actual diff command, so use the man page to
understand the details of the format.

Testing command output is a frequent use case, so here's a simple test for a multline
message to illustrate the output:

```bash
test_multiline_message() {
  want="Hello,
world!"

  # this message contains a tab character
  message="Hello,
world	!"

  ## arrange -- nothing to do here
  ## act
  got=$(echo "$message")    # variables with newlines require quotes when expanding

  ## assert
  [[ $got == "$want" ]] || {
    echo -e "multiline_message got didn't match want\n$(t.diff "$got" "$want")"
    return 1
  }
}
```

This gives:

```bash
=== RUN   test_multiline_message
multiline_message got didn't match want
2c2
< world^I!
---
> world!
--- FAIL: test_multiline_message (4 ms)
FAIL (9 ms)
```

## Summary

That's a description of the basic capabilities of tesht, which is a fairly simple wrapper
around functionality in your own tests.  Knowing how to write the tests is actually the key
to understanding how to use tesht.  Hopefully this readme gives a good basis to start from.

Table-driven tests in Go follow other useful conventions as well, such as parameterizing
dependencies with the `fields` struct.  Understanding how they work can inform your tesht
testing.  I encourage you to work with them in Go, time permitting.
