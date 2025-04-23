# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'

# test_tesht.test tests that the test function tests.
test_tesht.test() {
  ## arrange
  timestamp() { return 0; }
  tesht.Init timestamp

  ## act
  # run the command in a subshell and check counting happened
  local rc got
  got=$(
    tesht.test testdummy_RunTwoSubtests
    exit $TestCountT
  ) && rc=$? || rc=$?

  ## assert
  # assert counting was done
  (( rc == 2 )) || {
    echo "${NL}TestCountT is wrong. want: 2, got: $TestCountT$NL"
    return 1
  }
}

# A dummy test run by test_tesht.test.
# The point of this test is not to pass or fail but to simply run
# two subtest cases so they may be counted in the results.
testdummy_RunTwoSubtests() {
  subtest() { :; }                      # necessary, always passes
  local -A case=([name]=slug)           # name is required in this map
  tesht.Run test_RunTwoSubTests case1   # it's ok to call tesht.Run with the same subtest twice
  tesht.Run test_RunTwoSubTests case1
}
