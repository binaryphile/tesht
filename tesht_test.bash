# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'

# test_tesht.in tests that the in function works.
test_tesht.in() {
  ## arrange
  # When running this test, the outer tesht instance is protected from modifications by employing a subshell,
  # so we can modify its dependencies safely.
  timestamp() { return 0; }
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

# test_tesht.test tests that the test function tests.
test_tesht.test() {
  ## arrange
  timestamp() { return 0; }
  tesht.InitModule timestamp

  local -A case1=(
    [name]='count two subtests'
    [funcname]='runTwoSubtests'
    [want]=2
  )

  local -A case2=(
    [name]='count one subtest'
    [funcname]='runOneSubtest'
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

  tesht.Run test_tesht.test ${!case@}
}

# Test functions for different scenarios
runTwoSubtests() {
  subtest() { :; }                  # necessary, always passes
  local -A case=([name]=slug)       # name is required in this map
  tesht.Run runTwoSubtests case     # it's ok to call tesht.Run with the same subtest twice
  tesht.Run runTwoSubtests case
}

runOneSubtest() {
  subtest() { :; }
  local -A case=([name]=slug)
  tesht.Run runOneSubtest case
}
