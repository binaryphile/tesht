#!/usr/bin/env bash

# This is a sample test file.  To use it, copy the file to a name that ends in `_test.bash`
# (note the underscore rather than hyphen).

source ./somefunc.bash

test_somefunc() {
  ## arrange

  # temporary directory
  trapcmd=$(t.mktemp) || return   # fail if can't make dir
  trap $trapcmd EXIT              # always clean up
  cd $dir

  subject=${FUNCNAME#test_}   # the name of the function under test
  want='some output'          # the desired command output

  ## act

  # run the command and capture the output and result code
  got=$($subject args to command go here 2>&1)
  rc=$?

  ## assert

  # assert no error
  (( rc == 0 )) || {
    echo -e "$subject() error = $rc, want: 0\n$got"
    return 1
  }

  # assert that we got the wanted output
  [[ $got == "$want" ]] || {
    echo -e "$subject() got doesn't match want:\n$(t.diff "$got" "$want")"
    return 1
  }
}
