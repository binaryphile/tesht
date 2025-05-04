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
    [command]="tesht.Main $'test_success\ntest_failure' dummy_test.bash"
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
    echoln  "test_success() { :; }" \
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

echoln() {
  local IFS=$NL
  echo "$*"
}
