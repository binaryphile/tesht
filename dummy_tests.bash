# A dummy test run by tesht_test.bash#test_tesht.testFile.
# The point of this test is not to pass or fail but to simply run
# two subtest cases so they may be counted in the results.
test_RunTwoSubTests() {
  subtest() { :; }                      # necessary, always passes
  local -A case1=([name]=slug)          # name is required in this map
  tesht.Run test_RunTwoSubTests case1   # it's ok to call tesht.Run with the same subtest twice
  tesht.Run test_RunTwoSubTests case1
}
