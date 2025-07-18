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

    [command]='tesht.Main "" dummy_test.bash'
    [want]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
=== $RunT$Tab$Tab${Tab}test_failure$CR--- $FailT${Tab}0ms${Tab}${YellowT}test_failure$ResetT
=== $RunT$Tab$Tab${Tab}test_thirdWheel$CR--- $PassT${Tab}0ms${Tab}test_thirdWheel
$FailT$Tab${Tab}0ms
2/3"
  )

  local -A case2=(
    [name]='run two requested tests and skip a third'

    [command]='tesht.Main "test_success${NL}test_failure" dummy_test.bash'
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
    local dir
    tesht.MktempDir dir || return 128  # fatal if can't make dir
    cd $dir

    # test file
    echoLines "test_success() { :; }" \
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

# test_AssertGot tests that AssertGot identifies whether two inputs are equal.
test_AssertGot() {
  local -A case1=(
    [name]='return 0 and no output if inputs match'

    [command]='tesht.AssertGot match match'
    [want]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 1 and show a diff if inputs do not match'

    [command]='tesht.AssertGot no match'
    [want]=$'\n\ngot does not match want:\n< no\n---\n> match\n\nuse this line to update want to match:\n    want=\'no\''
    [wantrc]=1
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local got # can't combine with below when getting rc
    got=$(eval "$command") && local rc=$? || local rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$got" "$want"
    END
  }

  tesht.Run ${!case@}
}

# test_AssertRC tests that AssertRC identifies whether two result codes are equal.
test_AssertRC() {
  local -A case1=(
    [name]='return 0 and no output if inputs match'

    [command]='tesht.AssertRC 1 1'
    [want]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 1 and show an error message if inputs do not match'

    [command]='tesht.AssertRC 0 1'
    [want]=$'\n\nerror: rc = 0, want: 1'
    [wantrc]=1
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc # can't combine with below when getting rc
    got=$(eval "$command") && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$got" "$want"
    END
  }

  tesht.Run ${!case@}
}

# test_ListOf tests that ListOf joins arguments with newlines.
test_ListOf() {
  local -A case1=(
    [name]='no arguments returns empty string'

    [command]='tesht.ListOf'
    [want]=''
  )

  local -A case2=(
    [name]='single argument returns the argument'

    [command]='tesht.ListOf "hello"'
    [want]='hello'
  )

  local -A case3=(
    [name]='multiple arguments joined with newlines'

    [command]='tesht.ListOf "first" "second" "third"'
    [want]=$'first\nsecond\nthird'
  )

  local -A case4=(
    [name]='handles arguments with spaces'

    [command]='tesht.ListOf "hello world" "foo bar"'
    [want]=$'hello world\nfoo bar'
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local got=$(eval "$command")

    ## assert
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_Inherit tests that Inherit creates an array from array notation when a key is plural.
test_Inherit() {
  ## arrange
  local -A map=([values]='( 0 1 )')

  ## act
  local got rc
  eval "$(tesht.Inherit map)" && rc=$? || rc=$?
  got=$(declare -p values)

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertRC $rc 0
    tesht.AssertGot "$got" 'declare -a values=([0]="0" [1]="1")'
  END
}

# test_test tests that test tests.
test_test() {
  local -A case1=(
    [name]='report a failing subtest'

    [command]='tesht.test "$testSource" test_fail'
    [testSource]='test_fail() {
      local -A case=([name]=slug)
      subtest() { return 1; }
      tesht.Run case
    }'
    [want]="=== $RunT$Tab$Tab${Tab}test_fail/slug$CR--- $FailT${Tab}0ms${Tab}${YellowT}test_fail/slug$ResetT"
  )

  local -A case2=(
    [name]='report a fatal subtest'

    [command]='tesht.test "$testSource" test_fatal'
    [testSource]='test_fatal() {
      local -A case=([name]=slug)
      subtest() { return 128; }
      tesht.Run case
    }'
    [want]="=== $RunT$Tab$Tab${Tab}test_fatal/slug$CR--- $FatalT${Tab}0ms${Tab}${YellowT}test_fatal/slug$ResetT"
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local got rc
    got=$(eval "$command") && rc=$? || rc=$?

    ## assert
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_StartHttpServer tests that StartHttpServer starts a server and handles errors.
test_StartHttpServer() {
  ## arrange

  # temporary directory
  local dir
  tesht.MktempDir dir || return 128  # fatal if can't make dir
  cd $dir

  # Create a test file for the server to serve
  echo "test content" >index.html

  local pid
  pid=$(tesht.StartHttpServer 8080) || return 128   # fatal if can't start server
  tesht.Defer "kill $pid"

  ## act
  local got rc
  got=$(curl -fsSL http://localhost:8080/index.html) && rc=$? || rc=$?

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertRC $rc 0
    tesht.AssertGot "$got" "test content"
  END
}

## helpers

echoLines() {
  local IFS=$NL
  echo "$*"
}
