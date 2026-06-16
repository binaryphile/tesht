# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
NL=$'\n'
CR=$'\r'
Tab=$'\t'

# Path to the tesht script under test. Captured at source time before any test cd's away.
TESHT_PATHT=$(realpath -- "${BASH_SOURCE%/*}/tesht")

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
    [name]='-run regex alternation runs two tests and skips a third'

    [command]='tesht.Main "test_success|test_failure" dummy_test.bash'
    [want]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
=== $RunT$Tab$Tab${Tab}test_failure$CR--- $FailT${Tab}0ms$Tab${YellowT}test_failure$ResetT
$FailT$Tab${Tab}0ms
1/2"
  )

  local -A case3=(
    [name]='report FAIL and exit 2 when no tests match filter'

    [command]='tesht.Main "test_nonexistent" dummy_test.bash'
    [want]="${FailT}${Tab}${Tab}0ms
0/0"
    [wantrc]=2
  )

  local -A case4=(
    [name]='-run anchored regex runs only exact match'

    [command]='tesht.Main "^test_success\$" dummy_test.bash'
    [want]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
$PassT$Tab${Tab}0ms
1/1"
  )

  local -A case5=(
    [name]='-run substring (unanchored) matches multiple by partial name'

    [command]='tesht.Main "succ" dummy_test.bash'
    [want]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
$PassT$Tab${Tab}0ms
1/1"
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
    local got rc
    got=$(eval "$command") && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertGot "$got" "$want"
      [[ -z ${wantrc:-} ]] || tesht.AssertRC $rc $wantrc
    END
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

# test_Smoke tests that Smoke asserts a command's exit code matches the expected value.
test_Smoke() {
  local -A case1=(
    [name]='return 0 and no output when expected rc matches actual'

    [command]='tesht.Smoke 0 true'
    [want]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 0 when an intentionally-failing command matches expected nonzero rc'

    [command]='tesht.Smoke 1 false'
    [want]=''
    [wantrc]=0
  )

  local -A case3=(
    [name]='return 1 and report the mismatch when actual rc differs from expected'

    [command]='tesht.Smoke 0 false'
    [want]=$'\n\nFAIL: expected rc=0, got rc=1 from: false\n\n\n  output: '
    [wantrc]=1
  )

  local -A case4=(
    [name]='accept optional -- separator before the command'

    [command]='tesht.Smoke 0 -- true'
    [want]=''
    [wantrc]=0
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

# test_cli_positional_file verifies a positional file arg is recognized + executed end-to-end.
test_cli_positional_file() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  echoLines "test_one() { :; }" >dummy_test.bash

  local got rc
  got=$($TESHT_PATHT dummy_test.bash 2>&1) && rc=$? || rc=$?

  [[ $got == *test_one* ]] || { tesht.Log "expected 'test_one' in output, got: $got"; return 1; }
  [[ $got == *PASS* ]] || { tesht.Log "expected 'PASS' marker in output, got: $got"; return 1; }
  tesht.AssertRC $rc 0
}

# test_cli_multiple_positional_files verifies that two positional files are both executed.
test_cli_multiple_positional_files() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  echoLines "test_foo() { :; }" >foo_test.bash
  echoLines "test_bar() { :; }" >bar_test.bash

  local got rc
  got=$($TESHT_PATHT foo_test.bash bar_test.bash 2>&1) && rc=$? || rc=$?

  [[ $got == *test_foo* ]] || { tesht.Log "expected 'test_foo' in output, got: $got"; return 1; }
  [[ $got == *test_bar* ]] || { tesht.Log "expected 'test_bar' in output, got: $got"; return 1; }
  tesht.AssertRC $rc 0
}

# test_cli_run_flag_subprocess verifies -run REGEXP and -run=REGEXP forms filter test names.
test_cli_run_flag_subprocess() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  echoLines "test_one() { :; }" "test_two() { :; }" >dummy_test.bash

  # -run REGEXP (space-separated form)
  local got
  got=$($TESHT_PATHT -run test_one dummy_test.bash 2>&1)
  [[ $got == *test_one* ]] || { tesht.Log "space-form: missing test_one in: $got"; return 1; }
  [[ $got != *test_two* ]] || { tesht.Log "space-form: test_two should be filtered out: $got"; return 1; }

  # -run=REGEXP (equals-syntax form)
  got=$($TESHT_PATHT -run=test_two dummy_test.bash 2>&1)
  [[ $got == *test_two* ]] || { tesht.Log "equals-form: missing test_two in: $got"; return 1; }
  [[ $got != *test_one* ]] || { tesht.Log "equals-form: test_one should be filtered out: $got"; return 1; }

  # Flag-after-positional (interleaved order): regression guard for impl /i pass
  # finding that the original options-then-positional parser loop broke on the
  # docs-promised `tesht my_test.bash -run TestFoo` shape.
  got=$($TESHT_PATHT dummy_test.bash -run test_one 2>&1)
  [[ $got == *test_one* ]] || { tesht.Log "flag-after-positional: missing test_one in: $got"; return 1; }
  [[ $got != *test_two* ]] || { tesht.Log "flag-after-positional: test_two should be filtered out: $got"; return 1; }
}

# test_cli_non_file_positional_errors verifies the inverted guard catches test-name-style positionals.
test_cli_non_file_positional_errors() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir

  local got rc=0
  got=$($TESHT_PATHT test_MyFunc 2>&1) || rc=$?

  tesht.AssertRC $rc 2
  [[ $got == *"does not look like a test file"* ]] \
    || { tesht.Log "missing 'does not look like a test file' in stderr: $got"; return 1; }
  [[ $got == *"did you mean: tesht -run test_MyFunc"* ]] \
    || { tesht.Log "missing 'did you mean: tesht -run' in stderr: $got"; return 1; }
}

# test_cli_positional_directory verifies a directory arg expands to *_test.bash files (shallow).
test_cli_positional_directory() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub
  echoLines "test_a() { :; }" >sub/a_test.bash
  echoLines "test_b() { :; }" >sub/b_test.bash

  local got rc
  got=$($TESHT_PATHT sub/ 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $got == *test_a* ]] || { tesht.Log "expected 'test_a' in output, got: $got"; return 1; }
  [[ $got == *test_b* ]] || { tesht.Log "expected 'test_b' in output, got: $got"; return 1; }
}

# test_cli_positional_directory_shallow verifies discovery does NOT recurse.
test_cli_positional_directory_shallow() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub/nested
  echoLines "test_top() { :; }" >sub/top_test.bash
  echoLines "test_deep() { :; }" >sub/nested/deep_test.bash

  local got rc
  got=$($TESHT_PATHT sub/ 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $got == *test_top* ]] || { tesht.Log "expected 'test_top' in output, got: $got"; return 1; }
  [[ $got != *test_deep* ]] || { tesht.Log "test_deep should NOT have been discovered (no recursion), got: $got"; return 1; }
}

# test_cli_positional_directory_empty verifies an empty dir reports a clear error.
test_cli_positional_directory_empty() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p empty

  local got rc=0
  got=$($TESHT_PATHT empty/ 2>&1) || rc=$?

  tesht.AssertRC $rc 2
  [[ $got == *"no *_test.bash files in directory: empty/"* ]] \
    || { tesht.Log "missing expected empty-dir error in stderr: $got"; return 1; }
}

# test_cli_positional_directory_and_file verifies dir + explicit file both run.
test_cli_positional_directory_and_file() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub
  echoLines "test_in_dir() { :; }" >sub/x_test.bash
  echoLines "test_explicit() { :; }" >other_test.bash

  local got rc
  got=$($TESHT_PATHT sub/ other_test.bash 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $got == *test_in_dir* ]] || { tesht.Log "expected 'test_in_dir' in output, got: $got"; return 1; }
  [[ $got == *test_explicit* ]] || { tesht.Log "expected 'test_explicit' in output, got: $got"; return 1; }
}

# test_cli_positional_directory_with_run_filter verifies -run filters tests discovered from a dir.
test_cli_positional_directory_with_run_filter() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub
  echoLines "test_keep() { :; }" "test_skip() { :; }" >sub/x_test.bash

  local got rc
  got=$($TESHT_PATHT -run test_keep sub/ 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $got == *test_keep* ]] || { tesht.Log "expected 'test_keep' in output, got: $got"; return 1; }
  [[ $got != *test_skip* ]] || { tesht.Log "test_skip should be filtered out, got: $got"; return 1; }
}

## helpers

echoLines() {
  local IFS=$NL
  echo "$*"
}
