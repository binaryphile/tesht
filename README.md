# tesht - bash testing inspired by Go's table tests

**tesht** is a command-line tool for testing Bash code.  By itself, the command `tesht`
searches for files in the current directory ending in `_test.bash`.  It runs any test
functions it finds, functions having names starting with `test_`.  Each function and its
success or failure is then reported in a succinct format, along with timing measurements.
If the test failed, the test output is shown as well.

## Features

- simple naming conventions - e.g. `test_myfunc()` in `myfunc_test.bash`
- output suppression - only see function output when tests fail
- reporting - individual and overall test results and timing


## Example

Tests typically follow the so-called "3 A's" pattern of [Arrange, Act, Assert]:

[Arrange, Act, Assert]: https://automationpanda.com/2020/07/07/arrange-act-assert-a-pattern-for-writing-good-tests/

- *arrange* the necessary test dependencies
- *act* with the system-under-test, i.e. the thing we are testing
- *assert* what the resulting state of affairs should be and flag the differences

The following test function appears in the file `ln_test.bash`:

```bash
# test_ln tests the shell's `ln` symlink command.
# A temporary directory is created as a workspace and is removed afterward.
# The test makes a symlink in the workspace with `ln -sf`.
test_ln() {
  # arrange

  # temporary directory
  dir=$(mktemp -d /tmp/tesht.XXXXXX)
  [[ $dir == /*/*/ ]] || t.fail "couldn't make temporary directory"
  trap "rm -rf $dir" EXIT # always clean up
  cd $dir

  # set positional args for command
  eval "set -- $args"

  # act

  # run the command and capture the result code
  got=$(ln $* 2>&1) && rc=$? || rc=$?

  # assert

  # if this is a test for error behavior, check it
  [[ -v wanterr ]] && {
    (( rc == wanterr )) && return
    echo -e "task.ln error = $rc, want: $wanterr\n$got"
    return 1
  }

  # assert no error
  (( rc == 0 )) || {
    echo -e "task.ln error = $rc, want: 0\n$got"
    return 1
  }

  # assert that the symlink was made
  [[ -L $2 ]] || {
    echo -e "task.ln expected $2 to be symlink\n$got"
    return 1
  }

  # assert that we got the wanted output
  [[ $got == "$want" ]] || {
    echo -e "task.ln got doesn't match want:\n$(t.diff "$got" "$want")"
    return 1
  }
}
```
