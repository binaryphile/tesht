# Because we are being run by tesht, it is already loaded and doesn't need to be sourced.
IFS=$'\n'
set -o noglob

NL=$'\n'
CR=$'\r'
Tab=$'\t'

# Path to the tesht script under test. Captured at source time before any test cd's away.
TESHT_PATHT=$(realpath -- "${BASH_SOURCE%/*}/tesht")

# mockUnixMilli is a deterministic clock for tests: it always reports 0.
mockUnixMilli() { return 0; }

# test_Main tests that Main finds a test file executes it.
test_Main() {
  local -A case1=(
    [name]='run passing and failing tests from a file'

    [commandLines]='tesht.Main "" dummy_test.bash'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
=== $RunT$Tab$Tab${Tab}test_failure$CR--- $FailT${Tab}0ms${Tab}${YellowT}test_failure$ResetT
=== $RunT$Tab$Tab${Tab}test_thirdWheel$CR--- $PassT${Tab}0ms${Tab}test_thirdWheel
$FailT$Tab${Tab}0ms
2/3"
  )

  local -A case2=(
    [name]='name filter alternation runs two tests and skips a third'

    [commandLines]='tesht.Main "test_success|test_failure" dummy_test.bash'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
=== $RunT$Tab$Tab${Tab}test_failure$CR--- $FailT${Tab}0ms$Tab${YellowT}test_failure$ResetT
$FailT$Tab${Tab}0ms
1/2"
  )

  local -A case3=(
    [name]='report FAIL and exit 2 when no tests match filter'

    [commandLines]='tesht.Main "test_nonexistent" dummy_test.bash'
    [wantLines]="${FailT}${Tab}${Tab}0ms
0/0"
    [wantrc]=2
  )

  local -A case4=(
    [name]='anchored name filter runs only exact match'

    [commandLines]='tesht.Main "^test_success\$" dummy_test.bash'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
$PassT$Tab${Tab}0ms
1/1"
  )

  local -A case5=(
    [name]='unanchored name filter matches by partial name'

    [commandLines]='tesht.Main "succ" dummy_test.bash'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_success$CR--- $PassT${Tab}0ms${Tab}test_success
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
    echoLines 'test_success() { :; }' \
      'test_failure() { return 1; }' \
      'test_thirdWheel() { :; }' \
      >dummy_test.bash

    ## act
    local gotLines rc
    gotLines=$(eval "$commandLines") && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertGot "$gotLines" "$wantLines"
      [[ -z ${wantrc:-} ]] || tesht.AssertRC $rc $wantrc
    END
  }

  tesht.Run ${!case@}
}

# test_MainFatal tests that a FATAL test (rc 128) fails the overall verdict and exit status.
test_MainFatal() {
  local -A case1=(
    [name]='fatal test fails the overall verdict'

    [bodyLines]='test_fatal() { return 128; }'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_fatal$CR--- $FatalT${Tab}0ms${Tab}test_fatal
=== $RunT$Tab$Tab${Tab}test_ok$CR--- $PassT${Tab}0ms${Tab}test_ok
$FailT$Tab${Tab}0ms
1/2"
  )

  local -A case2=(
    [name]='fatal subtest fails the overall verdict'

    [bodyLines]='test_fatal() { local -A c=([name]=x); subtest() { return 128; }; tesht.Run c; }'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_fatal/x$CR--- $FatalT${Tab}0ms$Tab${YellowT}test_fatal/x$ResetT
=== $RunT$Tab$Tab${Tab}test_ok$CR--- $PassT${Tab}0ms${Tab}test_ok
$FailT$Tab${Tab}0ms
1/2"
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    local dir
    tesht.MktempDir dir || return 128
    cd $dir
    echoLines "$bodyLines" 'test_ok() { :; }' >fatal_test.bash

    ## act
    local gotLines rc
    gotLines=$(tesht.Main '' fatal_test.bash) && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertGot "$gotLines" "$wantLines"
      tesht.AssertRC $rc 1
    END
  }

  tesht.Run ${!case@}
}

# test_AssertGot tests that AssertGot identifies whether two inputs are equal.
test_AssertGot() {
  local -A case1=(
    [name]='return 0 and no output if inputs match'

    [commandLines]='tesht.AssertGot match match'
    [wantLines]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 1 and show a diff if inputs do not match'

    [commandLines]='tesht.AssertGot no match'
    [wantLines]=$'\n\ngot does not match want:\n< no\n---\n> match\n\nuse this line to update want to match:\n    want=\'no\''
    [wantrc]=1
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local gotLines # can't combine with below when getting rc
    gotLines=$(eval "$commandLines") && local rc=$? || local rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$gotLines" "$wantLines"
    END
  }

  tesht.Run ${!case@}
}

# test_AssertRC tests that AssertRC identifies whether two result codes are equal.
test_AssertRC() {
  local -A case1=(
    [name]='return 0 and no output if inputs match'

    [commandLines]='tesht.AssertRC 1 1'
    [wantLines]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 1 and show an error message if inputs do not match'

    [commandLines]='tesht.AssertRC 0 1'
    [wantLines]=$'\n\nerror: rc = 0, want: 1'
    [wantrc]=1
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local gotLines rc # can't combine with below when getting rc
    gotLines=$(eval "$commandLines") && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$gotLines" "$wantLines"
    END
  }

  tesht.Run ${!case@}
}

# test_Smoke tests that Smoke asserts a command's exit code matches the expected value.
test_Smoke() {
  local -A case1=(
    [name]='return 0 and no output when expected rc matches actual'

    [commandLines]='tesht.Smoke 0 true'
    [wantLines]=''
    [wantrc]=0
  )

  local -A case2=(
    [name]='return 0 when an intentionally-failing command matches expected nonzero rc'

    [commandLines]='tesht.Smoke 1 false'
    [wantLines]=''
    [wantrc]=0
  )

  local -A case3=(
    [name]='return 1 and report the mismatch when actual rc differs from expected'

    [commandLines]='tesht.Smoke 0 false'
    [wantLines]=$'\n\nFAIL: expected rc=0, got rc=1 from: false\n\n\n  output: '
    [wantrc]=1
  )

  local -A case4=(
    [name]='accept optional -- separator before the command'

    [commandLines]='tesht.Smoke 0 -- true'
    [wantLines]=''
    [wantrc]=0
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local gotLines rc # can't combine with below when getting rc
    gotLines=$(eval "$commandLines") && rc=$? || rc=$?

    ## assert
    tesht.Softly <<'    END'
      tesht.AssertRC $rc $wantrc
      tesht.AssertGot "$gotLines" "$wantLines"
    END
  }

  tesht.Run ${!case@}
}

# test_ListOf tests that ListOf joins arguments with newlines.
test_ListOf() {
  local -A case1=(
    [name]='no arguments returns empty string'

    [commandLines]='tesht.ListOf'
    [wantLines]=''
  )

  local -A case2=(
    [name]='single argument returns the argument'

    [commandLines]='tesht.ListOf "hello"'
    [wantLines]='hello'
  )

  local -A case3=(
    [name]='multiple arguments joined with newlines'

    [commandLines]='tesht.ListOf "first" "second" "third"'
    [wantLines]=$'first\nsecond\nthird'
  )

  local -A case4=(
    [name]='handles arguments with spaces'

    [commandLines]='tesht.ListOf "hello world" "foo bar"'
    [wantLines]=$'hello world\nfoo bar'
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local gotLines=$(eval "$commandLines")

    ## assert
    tesht.AssertGot "$gotLines" "$wantLines"
  }

  tesht.Run ${!case@}
}

# test_declareVar tests that declareVar detects arrays by value shape, not
# merely by a name ending in 's' (era memory a69e08ff25be; tesht #67489).
test_declareVar() {
  local -A case1=(
    [name]='plural name with array-shaped value declares an array'

    [commandLines]='tesht.declareVar names "(a b c)"'
    [wantLines]="declare -a names='(a b c)'"
  )

  local -A case2=(
    [name]='name ending in s but scalar value declares a scalar, not an array'

    [commandLines]='tesht.declareVar showStatus foo'
    [wantLines]="declare showStatus='foo'"
  )

  local -A case3=(
    [name]='trailing-underscore name with array-shaped value declares an array'

    [commandLines]='tesht.declareVar names_ "(a b)"'
    [wantLines]="declare -a names_='(a b)'"
  )

  local -A case4=(
    [name]='ordinary scalar name and value declares a scalar'

    [commandLines]='tesht.declareVar name foo'
    [wantLines]="declare name='foo'"
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    ## act
    local gotLines=$(eval "$commandLines")

    ## assert
    tesht.AssertGot "$gotLines" "$wantLines"
  }

  tesht.Run ${!case@}
}

# test_Inherit tests that Inherit creates an array from array notation when a key is plural.
test_Inherit() {
  ## arrange
  local -A map=([values]='( 0 1 )')

  ## act
  local gotLines rc
  eval "$(tesht.Inherit map)" && rc=$? || rc=$?
  gotLines=$(declare -p values)

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertRC $rc 0
    tesht.AssertGot "$gotLines" 'declare -a values=([0]="0" [1]="1")'
  END
}

# test_test tests that test tests.
test_test() {
  local -A case1=(
    [name]='report a failing subtest'

    [commandLines]='tesht.test "$testSource" test_fail'
    [testSource]='test_fail() {
      local -A case=([name]=slug)
      subtest() { return 1; }
      tesht.Run case
    }'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_fail/slug$CR--- $FailT${Tab}0ms${Tab}${YellowT}test_fail/slug$ResetT"
  )

  local -A case2=(
    [name]='report a fatal subtest'

    [commandLines]='tesht.test "$testSource" test_fatal'
    [testSource]='test_fatal() {
      local -A case=([name]=slug)
      subtest() { return 128; }
      tesht.Run case
    }'
    [wantLines]="=== $RunT$Tab$Tab${Tab}test_fatal/slug$CR--- $FatalT${Tab}0ms${Tab}${YellowT}test_fatal/slug$ResetT"
  )

  subtest() {
    local casename=$1

    ## arrange
    UnixMilliFuncT=mockUnixMilli
    eval "$(tesht.Inherit $casename)"

    ## act
    local gotLines rc
    gotLines=$(eval "$commandLines") && rc=$? || rc=$?

    ## assert
    tesht.AssertGot "$gotLines" "$wantLines"
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
  echo 'test content' >index.html

  local -i pid
  pid=$(tesht.StartHttpServer 8080) || return 128   # fatal if can't start server
  tesht.Defer "kill $pid"

  ## act
  local gotLines rc
  gotLines=$(curl -fsSL http://localhost:8080/index.html) && rc=$? || rc=$?

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertRC $rc 0
    tesht.AssertGot "$gotLines" "test content"
  END
}

# test_cli_positional_file verifies a positional file arg is recognized + executed end-to-end.
test_cli_positional_file() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  echoLines 'test_one() { :; }' >dummy_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT dummy_test.bash 2>&1) && rc=$? || rc=$?

  [[ $gotLines == *test_one* ]] || { tesht.Log "expected 'test_one' in output, got: $gotLines"; return 1; }
  [[ $gotLines == *PASS* ]] || { tesht.Log "expected 'PASS' marker in output, got: $gotLines"; return 1; }
  tesht.AssertRC $rc 0
}

# test_Defer_failingCommandDoesNotCorruptVerdict verifies tesht #67543's fix:
# a Defer'd cleanup command that fails on a redundant invocation (e.g. a
# second `kill` on an already-reaped PID) must not abort the EXIT trap under
# `set -e` and flip an already-passing test's reported verdict to FAIL.
test_Defer_failingCommandDoesNotCorruptVerdict() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  echoLines \
    'test_passes() {' \
    '  tesht.Defer "false"' \
    '  return 0' \
    '}' \
    >defer_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT defer_test.bash 2>&1) && rc=$? || rc=$?

  [[ $gotLines == *PASS* ]] || { tesht.Log "expected 'PASS' despite failing Defer, got: $gotLines"; return 1; }
  tesht.AssertRC $rc 0
}

# test_cli_multiple_positional_files verifies that two positional files are both executed.
test_cli_multiple_positional_files() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  echoLines 'test_foo() { :; }' >foo_test.bash
  echoLines 'test_bar() { :; }' >bar_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT foo_test.bash bar_test.bash 2>&1) && rc=$? || rc=$?

  [[ $gotLines == *test_foo* ]] || { tesht.Log "expected 'test_foo' in output, got: $gotLines"; return 1; }
  [[ $gotLines == *test_bar* ]] || { tesht.Log "expected 'test_bar' in output, got: $gotLines"; return 1; }
  tesht.AssertRC $rc 0
}

# test_cli_obsoleteFlags_rejected verifies the removed Go-style spellings (-run,
# -run=, bare -j, -j=N) and malformed -j/--jobs/--run values exit 2 with a message
# naming the problem, before any test runs.
test_cli_obsoleteFlags_rejected() {
  local -A case1=([name]='-run REGEXP'         [args]=$(tesht.ListOf -run test_one dummy_test.bash)   [want]='-run was removed; use --run')  # obsolete-flag-reject-test
  local -A case2=([name]='-run=REGEXP'         [args]=$(tesht.ListOf -run=test_one dummy_test.bash)   [want]='-run was removed; use --run')  # obsolete-flag-reject-test
  local -A case3=([name]='bare -j before file' [args]=$(tesht.ListOf -j dummy_test.bash)              [want]='requires a non-negative integer')  # obsolete-flag-reject-test
  local -A case4=([name]='-j last'             [args]=$(tesht.ListOf dummy_test.bash -j)              [want]='requires a non-negative integer')  # obsolete-flag-reject-test
  local -A case5=([name]='-j then flag'        [args]=$(tesht.ListOf -j -x dummy_test.bash)           [want]='requires a non-negative integer')  # obsolete-flag-reject-test
  local -A case6=([name]='-j=N'                [args]=$(tesht.ListOf -j=4 dummy_test.bash)            [want]='use -j N or --jobs=N')  # obsolete-flag-reject-test
  local -A case7=([name]='--jobs last'         [args]=$(tesht.ListOf dummy_test.bash --jobs)          [want]='--jobs requires a non-negative integer')
  local -A case8=([name]='--jobs=abc'          [args]=$(tesht.ListOf --jobs=abc dummy_test.bash)      [want]='--jobs requires a non-negative integer')
  local -A case9=([name]='--run last'          [args]=$(tesht.ListOf dummy_test.bash --run)           [want]='--run requires a regexp')
  local -A case10=([name]='--run then --'      [args]=$(tesht.ListOf --run -- dummy_test.bash)        [want]='--run requires a regexp')
  local -A case11=([name]='-j non-digit'       [args]=$(tesht.ListOf -jx dummy_test.bash)             [want]='-j requires a non-negative integer, got: x')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128
    cd $dir
    echoLines 'test_one() { :; }' >dummy_test.bash

    ## act
    local got_ rc
    got_=$($TESHT_PATHT $args 2>&1) && rc=$? || rc=$?

    ## assert
    tesht.AssertRC $rc 2
    [[ $got_ == *"$want"* ]] || { tesht.Log "expected '$want' in: $got_"; return 1; }
    [[ $got_ != *test_one* ]] || { tesht.Log "no test should run: $got_"; return 1; }
  }

  tesht.Run ${!case@}
}

# test_cli_posixFlags_accepted verifies the POSIX/GNU spellings of the name filter
# (--run REGEXP, --run=REGEXP) and the job count (-j N, -jN, --jobs N, --jobs=N).
test_cli_posixFlags_accepted() {
  local -A case1=([name]='--run separate'       [args]=$(tesht.ListOf --run test_one dummy_test.bash)      [want]=one)
  local -A case2=([name]='--run equals'         [args]=$(tesht.ListOf --run=test_one dummy_test.bash)      [want]=one)
  local -A case3=([name]='--run empty = all'    [args]=$(tesht.ListOf --run= dummy_test.bash)              [want]=both)
  local -A case4=([name]='--run dash-led value' [args]=$(tesht.ListOf --run '-*test_one' dummy_test.bash)  [want]=one)
  local -A case5=([name]='-j N'                 [args]=$(tesht.ListOf -j 4 dummy_test.bash)                [want]=both)
  local -A case6=([name]='-jN attached'         [args]=$(tesht.ListOf -j4 dummy_test.bash)                 [want]=both)
  local -A case7=([name]='--jobs N'             [args]=$(tesht.ListOf --jobs 4 dummy_test.bash)            [want]=both)
  local -A case8=([name]='--jobs=N'             [args]=$(tesht.ListOf --jobs=4 dummy_test.bash)            [want]=both)
  local -A case9=([name]='--run after file'     [args]=$(tesht.ListOf dummy_test.bash --run test_one)      [want]=one)

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    ## arrange
    local dir
    tesht.MktempDir dir || return 128
    cd $dir
    echoLines 'test_one() { :; }' 'test_two() { :; }' >dummy_test.bash

    ## act
    local got_ rc
    got_=$($TESHT_PATHT $args 2>&1) && rc=$? || rc=$?

    ## assert
    tesht.AssertRC $rc 0
    [[ $got_ == *test_one* ]] || { tesht.Log "expected test_one to run: $got_"; return 1; }
    case $want in
      one  ) [[ $got_ != *test_two* ]] || { tesht.Log "expected test_two filtered out: $got_"; return 1; };;
      both ) [[ $got_ == *test_two* ]] || { tesht.Log "expected test_two to run: $got_"; return 1; };;
    esac
  }

  tesht.Run ${!case@}
}

# test_cli_non_file_positional_errors verifies the inverted guard catches test-name-style positionals.
test_cli_non_file_positional_errors() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir

  local gotLines rc=0
  gotLines=$($TESHT_PATHT test_MyFunc 2>&1) || rc=$?

  tesht.AssertRC $rc 2
  [[ $gotLines == *"does not look like a test file"* ]] \
    || { tesht.Log "missing 'does not look like a test file' in stderr: $gotLines"; return 1; }
  [[ $gotLines == *"did you mean: tesht --run test_MyFunc"* ]] \
    || { tesht.Log "missing 'did you mean: tesht -run' in stderr: $gotLines"; return 1; }
}

# test_cli_positional_directory verifies a directory arg expands to *_test.bash files (shallow).
test_cli_positional_directory() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub
  echoLines 'test_a() { :; }' >sub/a_test.bash
  echoLines 'test_b() { :; }' >sub/b_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT sub/ 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $gotLines == *test_a* ]] || { tesht.Log "expected 'test_a' in output, got: $gotLines"; return 1; }
  [[ $gotLines == *test_b* ]] || { tesht.Log "expected 'test_b' in output, got: $gotLines"; return 1; }
}

# test_cli_positional_directory_shallow verifies discovery does NOT recurse.
test_cli_positional_directory_shallow() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub/nested
  echoLines 'test_top() { :; }' >sub/top_test.bash
  echoLines 'test_deep() { :; }' >sub/nested/deep_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT sub/ 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $gotLines == *test_top* ]] || { tesht.Log "expected 'test_top' in output, got: $gotLines"; return 1; }
  [[ $gotLines != *test_deep* ]] || { tesht.Log "test_deep should NOT have been discovered (no recursion), got: $gotLines"; return 1; }
}

# test_cli_positional_directory_empty verifies an empty dir reports a clear error.
test_cli_positional_directory_empty() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p empty

  local gotLines rc=0
  gotLines=$($TESHT_PATHT empty/ 2>&1) || rc=$?

  tesht.AssertRC $rc 2
  [[ $gotLines == *"no *_test.bash files in directory: empty/"* ]] \
    || { tesht.Log "missing expected empty-dir error in stderr: $gotLines"; return 1; }
}

# test_cli_positional_directory_and_file verifies dir + explicit file both run.
test_cli_positional_directory_and_file() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub
  echoLines 'test_in_dir() { :; }' >sub/x_test.bash
  echoLines 'test_explicit() { :; }' >other_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT sub/ other_test.bash 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $gotLines == *test_in_dir* ]] || { tesht.Log "expected 'test_in_dir' in output, got: $gotLines"; return 1; }
  [[ $gotLines == *test_explicit* ]] || { tesht.Log "expected 'test_explicit' in output, got: $gotLines"; return 1; }
}

# test_cli_positional_directory_with_run_filter verifies --run filters tests discovered from a dir.
test_cli_positional_directory_with_run_filter() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub
  echoLines 'test_keep() { :; }' 'test_skip() { :; }' >sub/x_test.bash

  local got_ rc
  got_=$($TESHT_PATHT --run test_keep sub/ 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0
  [[ $got_ == *test_keep* ]] || { tesht.Log "expected 'test_keep' in output, got: $got_"; return 1; }
  [[ $got_ != *test_skip* ]] || { tesht.Log "test_skip should be filtered out, got: $got_"; return 1; }
}

# test_cli_TESHT_TEST_FILE_env_var verifies tesht exports the test file's
# absolute path so test bodies can locate adjacent scripts without falling
# back to $PWD or git rev-parse. Inside the eval'd test source, $BASH_SOURCE
# refers to tesht itself, not the test file -- $TESHT_TEST_FILE is the fix.
test_cli_TESHT_TEST_FILE_env_var() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir
  mkdir -p sub
  echoLines \
    'test_envvar() {' \
    '  [[ -n ${TESHT_TEST_FILE:-} ]] || { echo "TESHT_TEST_FILE unset"; return 1; }' \
    '  [[ $TESHT_TEST_FILE == /* ]] || { echo "TESHT_TEST_FILE not absolute: $TESHT_TEST_FILE"; return 1; }' \
    '  [[ $TESHT_TEST_FILE == */sub/dummy_test.bash ]] || { echo "TESHT_TEST_FILE wrong: $TESHT_TEST_FILE"; return 1; }' \
    '  [[ -f $TESHT_TEST_FILE ]] || { echo "TESHT_TEST_FILE does not exist: $TESHT_TEST_FILE"; return 1; }' \
    '}' >sub/dummy_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT sub/dummy_test.bash 2>&1) && rc=$? || rc=$?

  tesht.AssertRC $rc 0 || { tesht.Log "output: $gotLines"; return 1; }
}

# test_assertion_failure_fails_test verifies that a mid-body assertion failure
# causes the test to FAIL even when a later command returns 0 (#25287).
# Pre-fix, $testname && rc=$? || rc=$? suppressed set -e inside the test body,
# so a failing AssertGot followed by a passing `:` would silently report PASS.
test_assertion_failure_fails_test() {
  local -A case1=(
    [name]='non-subtest: mid-body AssertGot failure overrides rc=0 from final cmd'

    [bodyLines]='test_silent_fail() {
      tesht.AssertGot a b
      :
    }'
    [testname]='test_silent_fail'
  )

  local -A case2=(
    [name]='non-subtest: mid-body AssertRC failure overrides rc=0 from final cmd'

    [bodyLines]='test_silent_fail_rc() {
      tesht.AssertRC 0 1
      :
    }'
    [testname]='test_silent_fail_rc'
  )

  local -A case3=(
    [name]='subtest: mid-body AssertGot failure inside tesht.Run subtest fails test'

    [bodyLines]='test_silent_fail_sub() {
      local -A case=([name]=slug)
      subtest() {
        tesht.AssertGot a b
        :
      }
      tesht.Run case
    }'
    [testname]='test_silent_fail_sub'
  )

  subtest() {
    local casename=$1

    ## arrange
    eval "$(tesht.Inherit $casename)"

    local dir
    tesht.MktempDir dir || return 128
    cd $dir

    echoLines "$bodyLines" >dummy_test.bash

    ## act
    local got_ rc=0
    got_=$($TESHT_PATHT --run $testname dummy_test.bash 2>&1) || rc=$?

    ## assert: tesht's overall exit was non-zero AND the test was reported FAIL
    tesht.Softly <<'    END'
      [[ $rc -ne 0 ]] || { tesht.Log "expected non-zero rc, got rc=$rc; output: $got_"; return 1; }
      [[ $got_ == *FAIL* ]] || { tesht.Log "expected FAIL marker in output, got: $got_"; return 1; }
      [[ $got_ == *$testname* ]] || { tesht.Log "expected '$testname' in output, got: $got_"; return 1; }
    END
  }

  tesht.Run ${!case@}
}

# test_Retry verifies the composable retry middleware (#37012 follow-up).
# Covers: success on first call, --on-exhaust warn (cleanup-race policy used
# by tesht.MktempDir), --on-exhaust fail (default), --on-exhaust silent,
# attempt-count contract, missing-command guard, and unknown-option guard.
# The exhaust-policy cases stub the wrapped command + sleep inside a capture
# subshell so the contract is exercised deterministically without depending
# on filesystem race timing.
test_Retry() {
  local -A case1=(
    [name]='success on first call returns 0 with no output'
    [commandLines]='tesht.Retry -- true'
    [wantrc]=0
    [wantLines]=''
  )

  local -A case2=(
    [name]='on-exhaust warn logs warning and returns 0'
    [commandLines]='sleep() { :; }; tesht.Retry --attempts 3 --on-exhaust warn -- false 2>&1'
    [wantrc]=0
    [wantSubstr]='warning: tesht.Retry: 3 attempts exhausted: false'
  )

  local -A case3=(
    [name]='on-exhaust fail (default) returns 1 with no output'
    [commandLines]='sleep() { :; }; tesht.Retry --attempts 3 -- false'
    [wantrc]=1
    [wantLines]=''
  )

  local -A case4=(
    [name]='on-exhaust silent returns 0 with no output'
    [commandLines]='sleep() { :; }; tesht.Retry --attempts 3 --on-exhaust silent -- false'
    [wantrc]=0
    [wantLines]=''
  )

  local -A case5=(
    [name]='attempts the command N times before giving up'
    # Counts attempts via a stub that appends to a file; expects exactly N.
    [commandLines]='counter=$(mktemp); attempt() { echo x >>"$counter"; return 1; }; sleep() { :; }; tesht.Retry --attempts 4 --on-exhaust silent -- attempt; wc -l <"$counter" | tr -d " "'
    [wantrc]=0
    [wantLines]='4'
  )

  local -A case6=(
    [name]='missing command after options errors with rc=2'
    [commandLines]='tesht.Retry --attempts 2 2>&1'
    [wantrc]=2
    [wantSubstr]='missing command after options'
  )

  local -A case7=(
    [name]='unknown option errors with rc=2'
    [commandLines]='tesht.Retry --bogus foo -- true 2>&1'
    [wantrc]=2
    [wantSubstr]='unknown option: --bogus'
  )

  local -A case8=(
    [name]='accepts trailing command without -- separator'
    [commandLines]='tesht.Retry --attempts 1 true'
    [wantrc]=0
    [wantLines]=''
  )

  subtest() {
    local casename=$1
    local wantSubstr=''
    eval "$(tesht.Inherit $casename)"

    ## act
    local gotLines rc=0
    gotLines=$(eval "$commandLines") && rc=$? || rc=$?

    ## assert: rc always; substring opt-in; exact-want opt-in (skipped if wantSubstr set)
    tesht.AssertRC $rc $wantrc || return 1
    [[ -z $wantSubstr ]] || [[ $gotLines == *"$wantSubstr"* ]] \
      || { tesht.Log "missing substring '$wantSubstr' in: $gotLines"; return 1; }
    [[ -n $wantSubstr ]] || tesht.AssertGot "$gotLines" "$wantLines"
  }

  tesht.Run ${!case@}
}

# test_cli_j_parallel_pass_count verifies -j N produces the same overall
# pass count and exit code as the serial path for the same file (#37833).
test_cli_j_parallel_pass_count() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir

  echoLines \
    'test_a() { :; }' \
    'test_b() { :; }' \
    'test_c() { :; }' \
    'test_d() { :; }' \
    'test_e() { :; }' \
    >many_test.bash

  local serialTail_ parallelTail_
  serialTail_=$($TESHT_PATHT many_test.bash 2>&1 | tail -1)
  parallelTail_=$($TESHT_PATHT -j 4 many_test.bash 2>&1 | tail -1)

  tesht.Softly <<'  END'
    tesht.AssertGot "$serialTail_" "5/5"
    tesht.AssertGot "$parallelTail_" "5/5"
  END
}

# test_cli_j_parallel_mixed_pass_fail verifies pass/fail bookkeeping and
# overall exit code under -j N when some tests fail (#37833). Without
# per-worker counter capture, the parent would see PassCountT=TestCountT=0
# (workers mutate local copies) and the `failed=1` signal would be lost.
test_cli_j_parallel_mixed_pass_fail() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir

  echoLines \
    'test_a() { :; }' \
    'test_b() { return 1; }' \
    'test_c() { :; }' \
    'test_d() { :; }' \
    'test_e() { return 1; }' \
    >mixed_test.bash

  local gotLines rc=0
  gotLines=$($TESHT_PATHT -j 3 mixed_test.bash 2>&1) || rc=$?

  tesht.Softly <<'  END'
    tesht.AssertRC $rc 1
    [[ $gotLines == *3/5* ]] || { tesht.Log "expected '3/5' in output, got: $gotLines"; return 1; }
    [[ $gotLines == *test_a* ]] || { tesht.Log "expected 'test_a' in output, got: $gotLines"; return 1; }
    [[ $gotLines == *test_e* ]] || { tesht.Log "expected 'test_e' in output, got: $gotLines"; return 1; }
  END
}

# test_cli_j_parallel_isolation verifies 20 replicated tests all pass under
# -j 4, exercising the per-test MktempDir + fail-flag isolation under
# concurrent execution (#37833 acceptance criterion 2).
test_cli_j_parallel_isolation() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir

  {
    local -i i
    for (( i = 1; i <= 20; i++ )); do
      printf 'test_rep%d() {\n  local d\n  tesht.MktempDir d || return 128\n  echo hello >"$d/marker"\n  [[ -f "$d/marker" ]] || return 1\n  [[ $(cat "$d/marker") == hello ]] || return 1\n}\n' $i
    done
  } >rep_test.bash

  local gotLines rc
  gotLines=$($TESHT_PATHT -j 4 rep_test.bash 2>&1) && rc=$? || rc=$?

  tesht.Softly <<'  END'
    tesht.AssertRC $rc 0
    [[ $gotLines == *20/20* ]] || { tesht.Log "expected '20/20' in output, got: $gotLines"; return 1; }
  END
}

# test_cli_j_runs_tests_concurrently verifies -j N runs a file's tests at the
# same time. Each fixture test marks itself started, then waits for all four
# marks: that rendezvous completes only if the tests overlap, however loaded
# the host is. The serial run is the control: there the first test waits
# alone, so it must fail.
test_cli_j_runs_tests_concurrently() {
  local dir
  tesht.MktempDir dir || return 128
  cd $dir

  local test
  for test in s1 s2 s3 s4; do
    echo "test_$test() { touch \$BarrierDir/$test; barrierWait; }"
  done >barrier_test.bash
  cat >>barrier_test.bash <<'  END'
  barrierWait() {
    local -i try
    for (( try = 0; try < BarrierTries; try++ )); do
      [[ -e $BarrierDir/s1 && -e $BarrierDir/s2 && -e $BarrierDir/s3 && -e $BarrierDir/s4 ]] && return 0
      sleep 0.1
    done
    return 1
  }
  END

  local parallelOut_ serialOut_
  mkdir par ser
  parallelOut_=$(BarrierDir=$dir/par BarrierTries=100 $TESHT_PATHT -j 4 barrier_test.bash 2>&1 | tail -1)
  serialOut_=$(BarrierDir=$dir/ser BarrierTries=3 $TESHT_PATHT barrier_test.bash 2>&1 | tail -1)

  tesht.Softly <<'  END'
    tesht.AssertGot "$parallelOut_" "4/4"
    [[ $serialOut_ != 4/4 ]] || { tesht.Log "control: serial run must not rendezvous, got $serialOut_"; return 1; }
  END
}

## helpers

echoLines() {
  local IFS=$NL
  echo "$*"
}
