#!/usr/bin/env bash

# This is a sample test file.  To use it, copy the file to a name that ends in `_test.bash`
# (note the underscore rather than hyphen).

source ./somecommand.bash   # if the command being tested is a function, source it

# Subtests are run with t.run.
test_somecommand() {
  command=${FUNCNAME#test_}

  # test case parameters

  local -A case1=(
    [name]='basic'        # case name that shows up in output
    [args]='some args'    # command arguments to the test command
    [want]='some output'  # the desired command output
  )

  local -A case2=(
    [name]='error'
    [args]='some args'
    [wanterr]=1           # the desired error result code
  )

  # subtest is the the test code run against the test cases.
  # command is the command under test.
  # casename is the name of an associative array holding at least the key "name".
  # Each subtest that needs a directory creates it in /tmp.
  subtest() {
    command=$1 casename=$2

    ## arrange

    # create variables from the keys/values of the test case map
    eval "$(t.inherit $casename)"

    # temporary directory
    dir=$(t.mktempdir) || return 128  # fatal if can't make dir
    trap "rm -rf $dir" EXIT           # always clean up
    cd $dir

    # set positional args
    eval "set -- $args"

    ## act

    # run the command and capture the output and result code
    got=$($command $* 2>&1)
    rc=$?

    ## assert

    # if this is a test for error behavior, check it
    [[ -v wanterr ]] && {
      (( rc == wanterr )) && return   # so long as the error is the expected one, return without error
      echo -e "    $command/$name: error = $rc, want: $wanterr\n$got"
      return 1
    }

    # assert no error
    (( rc == 0 )) || {
      echo -e "    $command/$name: error = $rc, want: 0\n$got"
      return 1
    }

    # assert that we got the wanted output
    [[ $got == "$want" ]] || {
      echo -e "    $command/$name got doesn't match want:\n$(t.diff "$got" "$want")"
      return 1
    }
  }

  failed=0
  for casename in ${!case@}; do
    t.run subtest $command $casename || {
      (( $? == 128 )) && return   # fatal
      failed=1
    }
  done

  return $failed
}
