NL=$'\n'

# test_testFile tests that testFile tracks subtest results.
# Subtests are run with tesht.Run.
test_tesht.testFile() {
  ## arrange

  # mock out a nondeterministic input, the current time
  tesht.timestamp() { return 0; }

  ## act

  # run the command and capture the output and result code
  local got rc
  got=$(tesht.testFile dummy_tests.bash 2>&1) && rc=$? || rc=$?

  ## assert

  # assert counting was done
  (( PassCountT == 0 )) || echo "${NL}tesht.testFile: PassCountT is not 0."
}
