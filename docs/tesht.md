# tesht

Tesht is the table-driven testing framework for bash scripts in this user's
ecosystem. Use it whenever you write or modify bash code that needs tests.
The `tesht` binary is on PATH; tests live in `*_test.bash` files alongside
the script under test.

## Invocation

```bash
tesht                              # run all test_* in *_test.bash files in cwd
tesht my_test.bash                 # run tests in one file
tesht foo_test.bash bar_test.bash  # multiple files
tesht -run TestMyFunction          # filter test names by regex (any file)
tesht my_test.bash -run TestFoo    # file + name filter
tesht -run=TestFoo my_test.bash    # equals-syntax variant
tesht -x                           # trace mode for debugging
```

Positional args are test files; `-run REGEXP` filters test names via bash native regex (`=~`). Empty regex matches every test. The `-run` flag accepts both `-run REGEXP` (space-separated) and `-run=REGEXP` (equals-syntax) forms. Matches Go's `go test [-run regexp] [files]` shape.

## Test discovery

Test files end in `_test.bash`. Test functions are named `test_*`. Tesht
picks them up automatically.

## Two patterns

**Single test** -- one case:

```bash
test_doThing() {
  ## arrange
  local input='foo' want='bar'

  ## act
  local got
  got=$(doThing "$input")

  ## assert
  tesht.AssertGot "$got" "$want"
}
```

**Table-driven** -- multiple cases sharing a body:

```bash
test_doThing() {
  local -A case1=([name]='basic'  [input]='foo' [want]='bar')
  local -A case2=([name]='edge'   [input]=''    [want]='')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"
    local got
    got=$(doThing "$input")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}
```

## Core API

- `tesht.AssertGot got want` -- compare strings, diff + copy-paste fix line on mismatch
- `tesht.AssertRC rc want` -- compare return codes
- `tesht.Smoke expected_rc [--] cmd [args...]` -- run a CLI smoke check; succeed iff actual rc matches expected. Use for ad-hoc CLI checks outside test functions where naive shell chains would propagate an intentional-failure rc as the script's overall exit code.
- `tesht.Softly <<'END' ... END` -- run multiple assertions, continue on failure
- `tesht.Run ${!case@}` -- iterate table cases through `subtest`
- `tesht.Inherit $casename` -- unpack an associative-array case into locals
- `tesht.Log msg` -- print from a test
- `tesht.MktempDir dir` -- temp dir with auto-cleanup; writes path into the
  named variable (out-param), registers `rm -rf` via `tesht.Defer`
- `tesht.Defer "command"` -- stack a command on the EXIT trap (FIFO)
- `tesht.Diff a b` -- unified diff
- `tesht.StartHttpServer [port]` -- HTTP fixture for tests

## Sourcing the script under test

If the script is meant to be executed directly, give it a test guard so
sourcing skips `main`:

```bash
# in the script:
[[ ${__MYSCRIPT_TESTING:-} ]] && return 2>/dev/null
```

In the test file, source with the guard set to bring functions into scope:

```bash
sourceHelpers() {
  __MYSCRIPT_TESTING=1 source "$ResumeListScript"
}
```

## Subshell isolation

Each test runs inside `( ... )`. Variable changes, `cd`, `set -e`/`-u`/
`pipefail`, function redefs, traps, `exec`, and `exit` all stay confined to
the test's subshell -- they cannot affect other tests or the runner.
Filesystem state outside `tesht.MktempDir` is shared, so clean up explicitly
when writing outside a temp dir.

## When to write a tesht test

- Whenever you change a bash script's behavior. The bash style guide treats
  test coverage as part of the change.
- Use Khorikov-aligned thinking: integration tests on the controller (the
  script's `main`), not unit tests on every internal helper. Assert
  observable stdout, mock only inter-system boundaries (commands like
  `tmux`, `date`), use the real filesystem inside `tesht.MktempDir`.
