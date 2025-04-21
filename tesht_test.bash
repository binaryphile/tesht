# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'

# test_testFile tests that a test with two subtests is counted properly.
test_tesht.testFile() {
  ## arrange
  timestamp() { return 0; }

  ## act
  # run the command in a subshell and check counting happened
  local rc got
  got=$(
    tesht.testFile timestamp dummy_tests.bash test_RunTwoSubtests
    exit $TestCountT
  ) && rc=$? || rc=$?

  ## assert
  # assert counting was done
  (( rc == 2 )) || {
    echo "${NL}tesht.testFile: TestCountT is wrong. want: 2, got: $TestCountT$NL"
    return 1
  }
}
