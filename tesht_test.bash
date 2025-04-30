# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'

# deterministic mock for time
timestamp() { return 0; }

# test_AssertGot returns an error and a help message if got != want.
# Otherwise it does nothing.
test_AssertGot() {
  ## arrange
  # The outer tesht instance is protected from this test's modifications by employing a subshell.
  tesht.InitModule timestamp

  local -A case1=(
    [name]='given got does not match want, output a message and return an error'
    [args]='(no match)'
    [wantrc]=1
    [want]="$NL${NL}got does not match want:$NL< no$NL---$NL> match$NL${NL}use this line to update want to match:$NL    want='no'"
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    unset -v want wantrc
    eval "$(tesht.Inherit $casename)" >&2

    ## act
    local got rc
    got=$(tesht.AssertGot "${args[@]}") && rc=$? || rc=$?

    ## assert
    # if this is a test for error behavior, check it
    if [[ -v wantrc ]]; then
      tesht.AssertRC $rc $wantrc "$got" || return
    else
      tesht.AssertRC $rc 0 "$got" || return
    fi

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run test_tesht.AssertGot ${!case@}
}

# test_in tests that the in function works.
test_in() {
  ## arrange
  # When running this test, the outer tesht instance is protected from modifications by employing a subshell,
  # so we can modify its dependencies safely.
  tesht.InitModule timestamp

  local -A case1=(
    [name]='detect an item in an array'
    [values]='(a b c)'
    [item]='b'
    [want]=0
  )

  local -A case2=(
    [name]='not detect an item not in an array'
    [values]='(a b c)'
    [item]='d'
    [want]=1
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got
    tesht.in values $item && got=$? || got=$?

    ## assert
    tesht.AssertGot $got $want
  }

  tesht.Run test_tesht.in ${!case@}
}

# test_test tests that the test function tests tests.
test_test() {
  ## arrange
  tesht.InitModule timestamp

  local -A case1=(
    [name]='print a pass message for success'
    [funcname]='testSuccess'
    [want]='a'
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=(tesht.test $funcname) && rc=$? || rc=$?

    ## assert
    tesht.AssertGot $got $want
  }

  tesht.Run test_tesht.test ${!case@}
}

# test_subtests_tesht.test tests that the test function tests.
test_test_subtests() {
  ## arrange
  tesht.InitModule timestamp

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

  tesht.Run test_subtest_tesht.test ${!case@}
}

# Mock test functions for different scenarios

testTwoSubtests() {
  subtest() { :; }                  # required
  local -A case=([name]=slug)       # name is required
  tesht.Run testTwoSubtests case    # it's ok to call tesht.Run with the same subtest twice
  tesht.Run testTwoSubtests case
}

testOneSubtest() {
  subtest() { :; }
  local -A case=([name]=slug)
  tesht.Run testOneSubtest case
}

testSuccess() { :; }
