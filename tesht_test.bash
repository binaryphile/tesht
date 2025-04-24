# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'

# test_tesht.test tests that the test function tests.
test_tesht.test() {
  ## arrange
  timestamp() { return 0; }
  tesht.Init timestamp

  local -A case1=(
    [name]='count two subtests'
    [funcname]='runTwoSubtests'
    [want]=1  # Should be 2, but we'll make it fail first
  )

  local -A case2=(
    [name]='count one subtest'
    [funcname]='runOneSubtest'
    [want]=2  # Should be 1, but we'll make it fail first
  )

  # subtest runs each test case
  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit "$casename")"

    ## act
    local rc got
    got=$(
      tesht.test "$funcname"
      exit $TestCountT
    ) && rc=$? || rc=$?

    ## assert
    (( rc == want )) || {
      echo "${NL}TestCountT is wrong. want: $want, got: $rc$NL"
      return 1
    }
  }

  tesht.Run test_tesht.test "${!case@}"
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
