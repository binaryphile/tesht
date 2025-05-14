# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'
CR=$'\r'
Tab=$'\t'

# deterministic mock for time
mockUnixMilli() { return 0; }

# test_Main tests that Main finds a test file executes it.
test_Main() {
  local -A case1=(
    [name]='run passing and failing tests from a file'

    [command]="tesht.Main '' dummy_test.bash"
    [want]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
=== $RunT$Tab$Tab${Tab}test_failure$CR--- $FailT${Tab}0ms${Tab}${YellowT}test_failure$ResetT
=== $RunT$Tab$Tab${Tab}test_thirdWheel$CR--- $PassT${Tab}0ms${Tab}test_thirdWheel
$FailT$Tab${Tab}0ms
2/3"
  )

  local -A case2=(
    [name]='run two requested tests and skip a third'

    [command]='tesht.Main "test_success${NL}test_failure" dummy_test.bash'
    [want]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
=== $RunT$Tab$Tab${Tab}test_failure$CR--- $FailT${Tab}0ms$Tab${YellowT}test_failure$ResetT
$FailT$Tab${Tab}0ms
1/2"
  )

  subtest() {
    local casename=$1

    ## arrange

    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    # temporary directory
    local dir=$(tesht.MktempDir) || return 128  # fatal if can't make dir
    trap "rm -rf $dir" EXIT                     # always clean up
    cd $dir

    # test file
    echoLines "test_success() { :; }" \
      "test_failure() { return 1; }" \
      "test_thirdWheel() { :; }" \
      >dummy_test.bash

    ## act
    local got=$(eval "$command")

    ## assert
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_AssertGot tests that AssertGot identifies whether two inputs are equal.
test_AssertGot() {
  local -A case1=(
    [name]='return 0 and no output if inputs match'

    [command]='tesht.AssertGot match match'
    [want]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 1 and show a diff if inputs do not match'

    [command]='tesht.AssertGot no match'
    [want]=$'\n\ngot does not match want:\n< no\n---\n> match\n\nuse this line to update want to match:\n    want=\'no\''
    [wantrc]=1
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local got # can't combine with below when getting rc
    got=$(eval "$command") && local rc=$? || local rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$got" "$want"
    END
  }

  tesht.Run ${!case@}
}

# test_AssertRC tests that AssertRC identifies whether two result codes are equal.
test_AssertRC() {
  local -A case1=(
    [name]='return 0 and no output if inputs match'

    [command]='tesht.AssertRC 1 1'
    [want]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 1 and show an error message if inputs do not match'

    [command]='tesht.AssertRC 0 1'
    [want]=$'\n\nerror: rc = 0, want: 1'
    [wantrc]=1
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc # can't combine with below when getting rc
    got=$(eval "$command") && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$got" "$want"
    END
  }

  tesht.Run ${!case@}
}

# test_test tests that test tests.
test_test() {
  local -A case1=(
    [name]='report a failing subtest'

    [command]='tesht.test "$testSource" test_fail'
    [testSource]='test_fail() { return 1; }'
    [want]="=== $RunT$Tab$Tab${Tab}test_fail$CR--- $FailT${Tab}0ms${Tab}${YellowT}test_fail$ResetT"
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=$(eval "$command") && rc=$? || rc=$?

    ## assert
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

## helpers

echoLines() {
  local IFS=$NL
  echo "$*"
}
