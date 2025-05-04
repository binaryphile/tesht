# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'
CR=$'\r'
Tab=$'\t'

# deterministic mock for time
mockUnixMilli() { return 0; }

# test_AssertGot returns an error and a help message if got != want.
# Otherwise it does nothing.
test_AssertGot() {
  local -A case1=(
    [name]='when got matches want, output nothing'
    [args]='(match match)'
    [want]=''
  )

  local -A case2=(
    [name]='when got does not match want, output a message and return an error'
    [args]='(no match)'
    [wantrc]=1
    [want]="$NL${NL}got does not match want:
< no
---
> match

use this line to update want to match:
    want='no'"
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    local wantrc=0
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=$(tesht.AssertGot "${args[@]}") && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$got" "$want"
    END
  }

  tesht.Run ${!case@}
}

# test_in tests that the in function works.
test_in() {
  local -A case1=(
    [name]='detect an item in an array'
    [values]='(a b c)'
    [item]='b'
    [wantrc]=0
  )

  local -A case2=(
    [name]='not detect an item not in an array'
    [values]='(a b c)'
    [item]='d'
    [wantrc]=1
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local rc
    tesht.in values $item && rc=$? || rc=$?

    ## assert
    tesht.AssertRC $rc $wantrc
  }

  tesht.Run ${!case@}
}

# test_Main tests that Main finds a test file executes it.
test_Main() {
  local -A case1=(
    [name]='run a test file'
    [command]="tesht.Main '' dummy_test.bash"
    [want]="=== $RunT$Tab$Tab${Tab}test_dummy$CR--- $PassT${Tab}0ms${Tab}test_dummy
$PassT$Tab${Tab}0ms
1/1"
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
    echo 'test_dummy() { :; }' >dummy_test.bash

    ## act
    local got=$(eval "$command")

    ## assert
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_test tests that the test function tests tests.
test_test() {
  local -A case1=(
    [name]='print a pass message for success'
    [funcname]='testSuccess'
    [want]="=== $RunT$Tab$Tab${Tab}testSuccess$CR--- $PassT${Tab}0ms${Tab}testSuccess"
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    local wantrc=0
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=$(tesht.test $funcname) && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$got" "$want"
    END
  }

  tesht.Run ${!case@}
}

# test_subtests_tesht.test tests that the test function tests.
test_test_subtests() {
  local -A case1=(
    [name]='count two subtests'
    [funcname]='testTwoSubtests'
    [want]=2
  )

  local -A case2=(
    [name]='count one subtest'
    [funcname]='testOneSubtest'
    [want]=1
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got
    (
      TestCountT=0
      tesht.test $funcname >/dev/null
      exit $TestCountT
    ) && got=$? || got=$?

    ## assert
    tesht.AssertGot $got $want
  }

  tesht.Run ${!case@}
}

# # Test for tesht.testFile
# test_testFile() {
#   local -A case1=(
#     [name]='run test file with no failures'
#     [filename]='tesht_test.bash'
#     [want]='PASS'
#   )
#
#   subtest() {
#     local casename=$1
#
#     ## arrange
#     eval "$(tesht.Inherit $casename)"
#
#     ## act
#     local got
#     got=$(tesht.testFile "$filename") && rc=$? || rc=$?
#
#     ## assert
#     tesht.AssertGot "$got" "$want"
#   }
#
#   tesht.Run test_testFile ${!case@}
# }

# Mock test functions for different scenarios
# They aren't run by tesht as tests themselves because they don't start with test_.

testOneSubtest() {
  subtest() { :; }
  local -A case=([name]='slug')
  tesht.Run case
}

testTwoSubtests() {
  subtest() { :; }                  # required
  local -A case=([name]='slug')     # name is required
  tesht.Run case    # it's ok to call tesht.Run with the same subtest twice
  tesht.Run case
}

testSuccess() { :; }
