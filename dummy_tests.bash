test_dummy() {
  subtest() { :; }
  local -A case1=([name]=basic)
  tesht.Run test_dummy case1
}
