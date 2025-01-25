# tesht - bash testing inspired by Go-style table tests

**tesht** is a library for testing Bash code.  In their simplest form, tests are just
functions that may make use of some helper functions from the library.  For example, here is
a simple test that checks the shell's `ln` command:

```bash
# test functions start with "test_".
# test_ln tests the shell's symlinking command.
test_ln() {
  dir=$(mktemp -d /tmp/tesht.XXXXXX)

  # arrange

  # temporary directory
  [[ -v dir ]] && {
    eval "dir=$dir"
    [[ $dir == /*/*/ ]]     # assert we got a directory
    trap "rm -rf $dir" EXIT # always clean up
    cd $dir
  }

  # set positional args for command
  eval "set -- $args"

  # act

  # run the command and capture the result code
  got=$(task.ln $* 2>&1) && rc=$? || rc=$?

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
