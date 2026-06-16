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
tesht scripts/                     # all *_test.bash in scripts/ (shallow)
tesht -run TestMyFunction          # filter test names by regex (any file)
tesht my_test.bash -run TestFoo    # file + name filter
tesht -run=TestFoo my_test.bash    # equals-syntax variant
tesht -x                           # trace mode for debugging
```

Positional args are test files or directories; `-run REGEXP` filters test names via bash native regex (`=~`). Empty regex matches every test. The `-run` flag accepts both `-run REGEXP` (space-separated) and `-run=REGEXP` (equals-syntax) forms. Matches Go's `go test [-run regexp] [files]` shape.

Directory args expand to `*_test.bash` files at one level deep (shallow; non-recursive). An empty directory errors. For nested test trees, pass an explicit glob (e.g. `tesht path/**/*_test.bash` with `shopt -s globstar`); built-in recursive discovery is deferred until a real use case surfaces.

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
  named variable (out-param), registers a retrying `rm -rf` via `tesht.Defer`
  (see "Cleanup race tolerance" below)
- `tesht.Defer "command"` -- stack a command on the EXIT trap (FIFO)
- `tesht.Retry [options] [--] cmd [args...]` -- composable retry middleware
  (see "Retry middleware" below)
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

## Script discovery

Test files that need to locate adjacent scripts (or other files relative to
themselves) cannot rely on `$BASH_SOURCE`. Tesht reads each test file's source
and runs it with `eval`, so inside test functions `BASH_SOURCE[0]` resolves to
the `tesht` binary, not the test file's path. The common idiom

```bash
Script=$(cd "$(dirname "$BASH_SOURCE")"; pwd)/scriptname  # WRONG under tesht
```

silently produces the wrong path.

Use `$TESHT_TEST_FILE` instead. Tesht exports it before evaluating each test
file's source; its value is the absolute path to the test file currently being
run:

```bash
Script=$(dirname "$TESHT_TEST_FILE")/scriptname
```

## Subshell isolation

Each test runs inside `( ... )`. Variable changes, `cd`, `set -e`/`-u`/
`pipefail`, function redefs, traps, `exec`, and `exit` all stay confined to
the test's subshell -- they cannot affect other tests or the runner.
Filesystem state outside `tesht.MktempDir` is shared, so clean up explicitly
when writing outside a temp dir.

## Mid-body assertion failures

A failing `tesht.AssertGot`, `tesht.AssertRC`, or `tesht.Smoke` anywhere in a
test body causes the test (or subtest) to FAIL, even if a later command in the
same body returns 0. Earlier versions of tesht silently passed such tests
because bash suppresses `set -e` inside functions invoked from `&& ||` compound
lists (the test runner's invocation shape), so an assertion's nonzero return
was masked by the function's final command. Tesht now sets a per-test
fail-flag sentinel that the assertion helpers touch on failure; the runner
checks it after the body returns and overrides `rc=0` to `rc=1` when set.

Practically, this means a test like

```bash
test_thing() {
  tesht.AssertGot "$got" "$want"   # mid-body — used to silent-pass
  : # final command rc=0
}
```

is now reported FAIL, as you'd expect. You can drop the per-assertion
`{ tesht.Log msg; return 1; }` boilerplate that older test files use to force
mid-body failures through.

The fail-flag is scoped to the test's BASHPID, so an assertion deliberately
exercised inside a nested `$(...)` or `(...)` -- e.g. when a helper's
self-tests capture its failure output -- runs at a different BASHPID and does
not taint the outer verdict.

Subtest failures inside `tesht.Run` are also propagated to tesht's overall
exit code (previously the subtest's FAIL marker reached stdout but the runner
still reported overall PASS / exit 0).

## Retry middleware

`tesht.Retry` wraps any command in a retry loop. Options precede the command;
the command + its args follow (optionally after a `--` separator). Shape
borrowed from fluentfp/web's `Adapt(handler, opts...)` — a core operation
modified by composable options rather than a fan-out of per-call wrappers.

```bash
tesht.Retry --attempts 5 --delay 0.2 --on-exhaust warn -- rm -rf -- "$dir"
```

Options:

- `--attempts N` — number of attempts (default 5)
- `--delay SEC` — sleep between attempts (default 0.2; fractional seconds OK)
- `--on-exhaust MODE` — behavior after attempts are exhausted (default `fail`):
  - `fail` — return 1
  - `warn` — log a warning to stderr + return 0
  - `silent` — return 0

The command's stderr from each attempt is suppressed; surface failures via
the exhaust policy or by wrapping a command that logs its own diagnostics.

## Cleanup race tolerance

`tesht.MktempDir`'s deferred cleanup is best-effort. If a test forks a child
process that outlives the test body (e.g. a background watcher), that child
may still be writing into the tmpdir when the EXIT trap fires. The cleanup
delegates to `tesht.Retry --attempts 5 --delay 0.2 --on-exhaust warn --
rm -rf -- <dir>`, which retries on `ENOTEMPTY`/`EBUSY` up to 5 times at 200ms
intervals (1s total) before giving up. On give-up it logs `warning:
tesht.Retry: 5 attempts exhausted: rm -rf -- <dir>` to stderr and returns 0,
so the test verdict reflects assertion results, not cleanup luck. If you see
the warning, look for a forked child that should be reaped before the test
body returns.

## When to write a tesht test

- Whenever you change a bash script's behavior. The bash style guide treats
  test coverage as part of the change.
- Use Khorikov-aligned thinking: integration tests on the controller (the
  script's `main`), not unit tests on every internal helper. Assert
  observable stdout, mock only inter-system boundaries (commands like
  `tmux`, `date`), use the real filesystem inside `tesht.MktempDir`.
