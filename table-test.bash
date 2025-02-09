#!/usr/bin/env bash

# This is a sample test file.  To use it, copy the file to a name that ends in `_test.bash`
# (note the underscore rather than hyphen).

source ./task.bash

sut=sut   # system under test

# Subtests are run with t.run.
test_sut() {
  local -A case1=(
    [name]='basic'
    [args]=''
    [want]=''
  )

  local -A case2=(
    [name]='error'
    [args]=''
    [wanterr]=1
  )

  # subtest runs each subtest.
  # case is expected to be the name of an associative array holding at least the key "name".
  # Each subtest that needs a directory creates it in /tmp.
  subtest() {
    casename=$1
    eval "$(t.inherit $casename)"  # create variables from the keys/values of the test case map

    ## arrange

    # temporary directory

    dir=$(mktemp -d /tmp/tesht.XXXXXX)
    [[ $dir == /tmp/tesht.* ]] || return

    trap "rm -rf $dir" EXIT # always clean up
    cd $dir

    # set positional args for command
    eval "set -- $args"

    ## act

    # run the command and capture the output and result code
    got=$($sut $* 2>&1)
    rc=$?

    ## assert

    # if this is a test for error behavior, check it
    [[ -v wanterr ]] && {
      (( rc == wanterr )) && return

      echo -e "    $sut/$name error = $rc, want: $wanterr\n$got"
      return 1
    }

    # assert no error
    (( rc == 0 )) || {
      echo -e "    $sut/$name error = $rc, want: 0\n$got"
      return 1
    }

    # assert that we got the wanted output
    [[ $got == "$want" ]] || {
      echo -e "    $sut/$name got doesn't match want:\n$(t.diff "$got" "$want")"
      return 1
    }
  }

  failed=0
  for casename in ${!case@}; do
    t.run subtest $casename || failed=1
  done

  return $failed
}
