#!/usr/bin/env bash

# This is a sample test file.  To use it, copy the file to a name that ends in `_test.bash`
# (note the underscore rather than hyphen).

source ./somecommand.bash   # if the command being tested is a function, source it

test_somecommand() {
  ## arrange

  # temporary directory
  dir=$(t.mktempdir) || return  # fail if can't make dir
  trap "rm -rf $dir" EXIT       # always clean up
  cd $dir

  command=${FUNCNAME#test_}   # the name of the function under test
  want='some output'          # the command's desired output

  ## act

  # run the command and capture the output and result code
  got=$($command args to command go here 2>&1)
  rc=$?

  ## assert

  # assert no error
  (( rc == 0 )) || {
    echo -e "$command: error = $rc, want: 0\n$got"
    return 1
  }

  # assert that we got the wanted output
  [[ $got == "$want" ]] || {
    echo -e "$command: got doesn't match want:\n$(t.diff "$got" "$want")"
    return 1
  }
}
