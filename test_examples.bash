#!/usr/bin/env bash

# This is a sample test file showing two different testing patterns.
# To use it, copy the file to a name that ends in `_test.bash`
# (note the underscore rather than hyphen).

source ./somecommand.bash   # if the command being tested is a function, source it

# SINGLE TEST PATTERN
# Use this pattern when you have one test case or when test cases
# don't share the same testing logic.
test_somecommand_single() {
  ## arrange

  # temporary directory
  local dir
  tesht.MktempDir dir || return 128  # fatal if can't make dir
  cd $dir

  local command=${FUNCNAME#test_}   # the name of the function under test
  local want='some output'          # the command's desired output

  ## act

  # run the command and capture the output and result code
  local got rc
  got=$($command args to command go here 2>&1) && rc=$? || rc=$?

  ## assert

  tesht.Softly <<'END'
    tesht.AssertRC $rc 0
    tesht.AssertGot "$got" "$want"
END
}

# TABLE-DRIVEN TEST PATTERN
# Use this pattern when you have multiple test cases that share
# the same testing logic but differ in inputs/outputs.
test_somecommand_table() {
  # Define test cases as associative arrays
  local -A case1=(
    [name]='basic functionality'  # case name that shows up in output
    [args]='some args'           # arguments to the command being tested
    [want]='some output'         # the command's desired output
  )

  local -A case2=(
    [name]='error handling'
    [args]='invalid args'
    [wantrc]=1                   # the desired error result code
    [want]='error message'       # expected error output
  )

  local -A case3=(
    [name]='edge case with special characters'
    [args]='args with "quotes" and $vars'
    [want]='processed output'
  )

  # subtest is the shared test logic run against each test case.
  # casename is the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # Load test case variables from the associative array
    eval "$(tesht.Inherit $casename)"

    # temporary directory
    local dir
    tesht.MktempDir dir || return 128  # fatal if can't make dir
    cd $dir

    local command=${FUNCNAME[1]#test_}  # the command under test

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(eval "$command $args" 2>&1) && rc=$? || rc=$?

    ## assert

    # Use wantrc if specified, otherwise expect success (0)
    local expectedrc=${wantrc:-0}
    
    tesht.Softly <<'END'
      tesht.AssertRC $rc $expectedrc
      tesht.AssertGot "$got" "$want"
END
  }

  # Run all test cases using the shared subtest logic
  tesht.Run ${!case@}
}

# HTTP SERVER TEST PATTERN
# Use this pattern when testing functions that make HTTP requests
# or when you need to test against a real HTTP server.
test_httpClient() {
  ## arrange

  # temporary directory for test files
  local dir
  tesht.MktempDir dir || return 128  # fatal if can't make dir
  cd $dir

  # Create test content for the server to serve
  echo "Hello, World!" > index.html
  
  # Start HTTP server and get the process ID
  local pid
  pid=$(tesht.StartHttpServer 8080) || return 128   # fatal if can't start server
  tesht.Defer "kill $pid"  # clean up server on exit

  ## act

  # Test HTTP GET request
  local response rc
  response=$(curl -fsSL http://localhost:8080/index.html) && rc=$? || rc=$?

  ## assert

  tesht.Softly <<'END'
    tesht.AssertRC $rc 0
    tesht.AssertGot "$response" "Hello, World!"
END
}