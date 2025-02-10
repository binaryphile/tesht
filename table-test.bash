#!/usr/bin/env bash

# This is a sample test file.  To use it, copy the file to a name that ends in `_test.bash`
# (note the underscore rather than hyphen).

source ./somefunc.bash

# Subtests are run with t.run.
test_somefunc() {
  subject=${FUNCNAME#test_}

  # test case parameters

  local -A case1=(
    [name]='basic'        # test name that shows up in output
    [args]='some args'    # command arguments to the test subject
    [want]='some output'  # the desired command output
  )

  local -A case2=(
    [name]='error'
    [args]='some args'
    [wanterr]=1           # the desired error result code
  )

  # Define the subtest that is run against cases.
  # casename is expected to be the name of an associative array holding at least the key "name".
  # Each subtest that needs a directory creates it in /tmp.
  subtest() {
    ## arrange

    # create variables from the keys/values of the test case map
    casename=$2
    eval "$(t.inherit $casename)"

    # temporary directory
    dir=$(mktemp -d /tmp/tesht.XXXXXX) || return        # fail if can't make dir
    trapcmd="[[ \"$dir\" == /*/* ]] && rm -rf '$dir'"   # belt-and-suspenders rm -rf
    trap $trapcmd EXIT                                  # always clean up
    cd $dir

    # set the command, positional args and output display name
    subject=$1
    eval "set -- $args"
    name="    $subject/$name()"

    ## act

    # run the command and capture the output and result code
    got=$($subject $* 2>&1)
    rc=$?

    ## assert

    # if this is a test for error behavior, check it
    [[ -v wanterr ]] && {
      # so long as the error is the expected one, return without error
      (( rc == wanterr )) && return

      echo -e "$name error = $rc, want: $wanterr\n$got"
      return 1
    }

    # assert no error
    (( rc == 0 )) || {
      echo -e "$name error = $rc, want: 0\n$got"
      return 1
    }

    # assert that we got the wanted output
    [[ $got == "$want" ]] || {
      echo -e "$name got doesn't match want:\n$(t.diff "$got" "$want")"
      return 1
    }
  }

  failed=0
  for casename in ${!case@}; do
    t.run subtest $subject $casename || failed=1
  done

  return $failed
}
