# UserSov Phase-3 Review of tesht

Phase-3 tooling-sweep review of tesht against `usersov-framework-guide.md`, per icarus #70311
(task tesht #79353). 9th review in the sweep, following era, agent-orchestration (now cascadia),
tandem-protocol, dotfiles, dojo, jeeves, evtctl, and mk.bash. Follows the guide's 8-block
grading-payload contract (§10).

**Process note**: no cross-vendor `/grade` round obtainable — autonomous mode is active (operator
stepped away, standing directive) and wl-copy paste-back is forbidden under autonomous mode
(operator-refined rule, era memory `10d230c441f1`/`ad7b7826dd88`: paste-back requires operator
presence). Self-review applied the same rubric and construction-check discipline the cross-vendor
rounds used elsewhere in this sweep; the Analysis grade below is capped one notch versus what a
cross-vendor-verified review would earn, per the guide's own discipline that unverified
self-assessment is a capped condition, not equivalent to independent verification. Logged as
`/variance` (event #79355) rather than a real grading round, matching the pattern dojo and jeeves
used under this same constraint earlier in this sweep.

**Scope framing note**: tesht is a small, single-file bash test runner (636 lines) with almost no
data flows of its own — no telemetry, no credential-file reads, no persistent stores beyond
ephemeral `/tmp` directories cleaned up at EXIT. The review's substance concentrates on two
capabilities the runner itself provides that create ambient exposure surfaces beyond what a test
author might expect from their own test's scope.

## Block 1 — Trigger, scope, profile, priorities

**Trigger**: Phase-3 tooling sweep (icarus #70311); tesht is the 9th of ~14 tools.

**Scope**: tesht's own implementation (`tesht:1-636`, complete), its default behavior with zero
consumer configuration, and the two capabilities (`-x`/`--trace`, `tesht.StartHttpServer`) that
create surfaces beyond a single test's own intended scope. Out of scope: the already-tracked
flag-convention issue (`tesht #79323`) — a STRIDE/usability finding, not a UserSov one.

**Profile**: Class H (standard professional/developer — the estate's operator).

**Class H modulations, applied throughout**:

- **Workplace-exposure priority** (custodial actor): any credential or workplace-identifying
  content passed as a command argument during a `--trace`'d test run becomes visible to whatever
  captures stderr (terminal scrollback, session transcripts, CI logs).
- **Long-horizon aggregation priority** (provider actor): N/A — tesht has no provider exit of its
  own; nothing it does persists or leaves the machine.
- **Moderate acceptable residual risk on availability-vs-confidentiality tradeoffs**: tesht's
  overall design favors developer visibility (showing exactly what ran, via the same class of
  ergonomics choice mk.bash's `mk.Cue` and `--trace` already made) over confidentiality by
  default — consistent with the estate-wide pattern this sweep keeps finding in its own tooling.

## Block 2 — Data classes + subjects

| Data class | Subject + role |
|---|---|
| Command arguments expanded via `--trace`'s global xtrace (may include credential-shaped values) | Operator — sole subject |
| Files in the current working directory when `tesht.StartHttpServer` runs (may include test fixtures, `.env`-shaped files, or other content depending on cwd) | Operator — sole subject; potential custodian role if a test's cwd happens to contain third-party data, though no such case was found in this estate's actual usage |

No third-party-data subject role applies to tesht's own surface directly — it doesn't touch
memory stores or transcripts. It can amplify exposure of whatever a test's own cwd or arguments
happen to contain, same amplifier framing prior reviews in this sweep have used for comparable
findings.

## Block 3 — Data-flow inventory

**Sources**: any command whose arguments get expanded after `-x`/`--trace` is passed; the current
working directory's contents when a test calls `tesht.StartHttpServer`.

**Processes**: tesht's own 636-line script, sourced/`eval`'d directly into the runner's shell
process for each test file (`tesht.test`, `tesht:409-479`) — no subprocess boundary between tesht
and the test bodies it runs.

**Stores**: none persistent. Ephemeral `/tmp/tesht.*` directories and files (test tmpdir helper,
fail-flag sentinel, parallel-run result buffers), all created via `mktemp` with default `0700`
permissions (verified directly: `mktemp -d /tmp/tesht.XXXXXX` produced `drwx------`), all cleaned
up via `tesht.Defer` + EXIT trap.

**Flows**: stderr (via `--trace`'s xtrace and the `tesht.Log`/failure-reporting helpers), stdout
(normal test-result reporting), and — only when a test explicitly calls it —
`tesht.StartHttpServer`'s HTTP flow: `127.0.0.1:$port` serving the cwd's files, reachable by any
local process for the duration of the test.

**Exits**: none tesht-authored beyond the two above. Any further exit belongs to whatever the
tested command itself does.

**Deletion paths**: N/A for tesht's own ephemeral temp dirs — cleaned up automatically via the
EXIT trap (retry-with-warn semantics per `tesht.Retry`, `tesht:230-275`, so a cleanup race doesn't
fail the test's own verdict).

**Trust boundaries**: user/machine boundary — tesht always runs with the operator's own
privileges, no privilege boundary of its own. The `tesht.StartHttpServer` helper introduces a
SEPARATE, narrower boundary: for the test's duration, the cwd's contents cross from
"reachable only by the operator's own processes" to "reachable by any local process on the
machine" via `127.0.0.1`.

**Derived surfaces**: `-x`/`--trace` (global xtrace), `tesht.StartHttpServer` (cwd-over-localhost
exposure).

## Block 4 — Per-property disposition

### TESHT-S1-TRACE-GLOBAL-XTRACE

- Primary property: 10 Substrate transparency/control failure

- Affected data + subject: every command argument expanded for the remainder of script execution
  after `--trace` is passed — operator, sole subject

- Surface/DFD element: `-x`/`--trace` flag (`tesht:38,572`)

- Actor capability + access path: n/a as a distinct actor — the disclosure surface is the flag's
  own designed behavior; any actor with read access to stderr's eventual destination (terminal
  scrollback, a captured session transcript, a CI log) inherits whatever was printed

- Scenario + enabling condition: `-x|--trace) set -x; shift;;` (`tesht:572`) enables bash's xtrace
  for the ENTIRE REMAINDER of script execution — not scoped to tesht's own internals. Because
  `tesht.test` `eval`'s the full test file's source (`tesht:428`), everything the test file itself
  does after that point is traced too, including whatever commands the test invokes.

- User impact: an operator debugging a failing test — often exactly when secret-bearing commands
  are already in play — reaches for `--trace` and gets every subsequent argument dumped to
  stderr. (Same inferred/plausibility framing mk.bash's MK-S2 used: this is a mechanism-level
  risk, not something observed in a specific dated incident this session.)

- Controls + evidence: none — bare `set -x`, no scoping, no redaction. Verified code-confirmed via
  direct source read.

- Assessment status + assumptions: assessed.

- Response or required capability: address — capability #1 (Block 8): a scoped/redacted trace
  mode (e.g., a limited `PS4` or subshell-scoped xtrace), or an explicit documented warning if
  scoping is judged disproportionate for a small tool like this.

- Residual risk + verification: residual until a scoping capability exists or a documented,
  labeled accept is recorded. Verify by confirming `--trace` no longer dumps a credential-shaped
  argument to stderr in a demonstration test run, or that a documented warning exists.

- Tags: live

### TESHT-S2-HTTPSERVER-CWD-DISCLOSURE

- Primary property: 5 Data disclosure

- Affected data + subject: any file in the current working directory at the time a test calls
  `tesht.StartHttpServer` — operator, sole subject (potential custodian role only if a test's cwd
  happens to contain third-party data; no such case identified in this estate's actual usage)

- Surface/DFD element: `tesht.StartHttpServer` (`tesht:386-406`)

- Actor capability + access path: any other local process on the same machine, during the window
  the server is running, via a plain HTTP GET to `127.0.0.1:$port`

- Scenario + enabling condition: `tesht.StartHttpServer` starts `python3 -m http.server $port
  --bind 127.0.0.1` rooted at the current directory (`tesht:394`), waits for it to become
  reachable (`tesht:397-401`), and returns its PID for the caller to manage. No scoping to
  specific files, no allowlist, and the helper's own doc-comment ("starts an http server in the
  current directory... waits until the server is ready before returning") does not name this
  exposure at all.

- User impact: whatever is in the test's cwd — which could include unrelated fixture data,
  `.env`-shaped files, or other content depending on what the test author's working directory
  happens to contain — becomes fetchable by any local process for as long as the server runs,
  without the test author necessarily intending to expose the WHOLE directory rather than just
  the fixture files their test actually needs.

- Controls + evidence: none within the helper itself. Localhost-only binding (`127.0.0.1`, not
  `0.0.0.0`) is a real, code-confirmed mitigating control — this is not network-exposed, only
  reachable from processes already running on the same machine.

- Assessment status + assumptions: assessed. No current known caller was found scoping this to a
  narrower directory than their actual cwd (not exhaustively audited across every consumer this
  session — same partial-consumer-audit caveat prior reviews in this sweep have applied to
  comparable findings).

- Response or required capability: address — capability #2 (Block 8): document the exposure
  explicitly in the helper's own doc-comment, and/or add a `--serve-dir`-style override so callers
  testing against a subdirectory aren't implicitly serving the whole cwd.

- Residual risk + verification: low-to-moderate — localhost-only scoping already bounds this to
  the local machine, not the network; residual exposure is to other local processes/users on a
  shared machine (a custodial-actor-relevant scenario per the guide's own actor model). Verify by
  confirming the doc-comment names the exposure, or that a scoped-directory option exists and a
  file outside the scoped directory is not fetchable while the server runs.

- Tags: live

## Disposition matrix

Surface (rows) × property (columns, 1–11). Every cell is a `RECORD-ID`, `N/A`, or `unknown`.

| Surface | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `-x`/`--trace` global xtrace | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | TESHT-S1-TRACE-GLOBAL-XTRACE | N/A |
| `tesht.StartHttpServer` cwd exposure | N/A | N/A | N/A | N/A | TESHT-S2-HTTPSERVER-CWD-DISCLOSURE | N/A | N/A | N/A | N/A | N/A | N/A |
| `eval`-based test execution (`tesht.test`, `tesht.Softly`) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |
| Ephemeral `/tmp` temp dirs (test tmpdir, fail-flag, parallel-run buffers) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |

**Reasoned N/A, grouped**:

- **Properties 1 (Linkability), 2 (Identifiability), 4 (Detectability), 6 (Unawareness &
  unintervenability), 7 (Non-compliance)**: N/A everywhere — tesht holds no state across
  invocations, correlates nothing, makes no external policy claims. Any credential- or
  identity-shaped content surfaced via TESHT-S1/S2 belongs to those records' classification, per
  the primary-harm rule, not a separate finding here.
- **Property 3 (Non-repudiation)**: N/A, same estate-wide reasoning every prior sweep review
  established — attribution is the declared posture for Class H work artifacts, not deniability.
- **Property 8 (Expungability failure) and 11 (Compulsion-resistance failure)**: N/A — tesht has
  no persistent store of its own to delete from or for a compulsion order to reach; ephemeral
  `/tmp` dirs are cleaned up automatically at EXIT.
- **Property 9 (Delegation integrity loss)**: N/A for the `eval`-based surfaces (`tesht.test`
  sourcing the full test file, `tesht.Softly` evaluating assertion lines from stdin). These
  execute only content the operator/test-author already supplies and trusts by construction —
  the same trust boundary any bash test runner has with the test files it's pointed at. No
  evidence was found of any consumer feeding delegate-controlled or otherwise untrusted content
  through either surface; classified N/A rather than left silent, consistent with how this sweep
  treated mk.bash's own analogous `eval`-based helpers (mk.bash #78873, property 9, closed to N/A
  with an exhaustive consumer search — tesht's own consumer base was not exhaustively re-audited
  this round given the tighter autonomous-mode time budget, so this N/A carries slightly less
  evidentiary weight than mk.bash's did).

## Block 5 — Controls + evidence

- Control: `mktemp -d` for all of tesht's own ephemeral temp directories produces `0700`
  (`drwx------`) permissions by default — verified directly this session (`mktemp -d
  /tmp/tesht.XXXXXX` then `ls -ld`). No cross-user exposure via loose temp-dir permissions on a
  shared machine.
- Control: `tesht.StartHttpServer` binds to `127.0.0.1` specifically, not `0.0.0.0` — verified
  code-confirmed (`tesht:394`). Bounds TESHT-S2's exposure to the local machine, not the network.
- Control: tesht has no telemetry, no credential-file reads, and no network call of its own
  initiative beyond the opt-in `StartHttpServer` helper (only invoked if a test explicitly calls
  it) and that same helper's own `curl` health-check against its own just-started server. Evidence
  status: code-confirmed (full 636-line source read, no other network-shaped calls found).
- Control: all of tesht's ephemeral state is cleaned up automatically via `tesht.Defer` +
  EXIT-trap, with retry-and-warn semantics (`tesht.Retry`) so a cleanup race doesn't corrupt the
  test's own pass/fail verdict. Evidence status: code-confirmed (`tesht:163-168`, `227-228`,
  `230-275`).

No internal contradictions were found among these controls.

## Block 6 — Assumptions, deferrals, accepted risks

Assumed: no current consumer's test suite passes credential-shaped arguments through commands
that would be traced under `--trace`, and no current consumer's cwd contains third-party or
credential-shaped files when calling `StartHttpServer` — neither assumption was exhaustively
re-verified against every known consumer this round (unverified, not asserted as fact).

Deferred: mechanism selection for both remediation capabilities (scoped-trace design,
`--serve-dir` option) — per the guide's own non-goal; protocol/gate integration — icarus #70312.

- Accepted risk (implicit, until TESHT-S1 remediation lands): any consumer that DOES pass a
  secret via a traced command's arguments discloses that secret to stderr today. Owner: operator.
  Rationale: no current known consumer usage confirmed to do this (not exhaustively audited); risk
  is prospective, not realized. Revisit trigger: any future usage confirmed to pass secret-shaped
  arguments through a traced command.
- Accepted risk (implicit, until TESHT-S2 remediation lands): any test's cwd containing sensitive
  content is exposed to other local processes for the server's runtime. Owner: operator.
  Rationale: localhost-only scoping already substantially bounds this; genuinely residual only on
  a shared/multi-user machine, which this estate's actual usage does not currently involve.
  Revisit trigger: tesht used on a shared machine, or a consumer's test cwd confirmed to contain
  sensitive content while calling this helper.

## Block 7 — Grade triplet (self-assessment)

```
Grade: B+           (payload complete across all 8 blocks; 2 threat records with code-confirmed
                     evidence; a 4-surface disposition matrix with reasoned-N/A coverage across
                     all 11 properties; evidence-status labeled per claim (verified/inferred/
                     unverified) throughout. CAPPED ONE NOTCH below what this analysis would
                     otherwise earn for lacking a cross-vendor adversarial round -- autonomous
                     mode, wl-copy forbidden, same constraint dojo/jeeves logged earlier in this
                     sweep.)
Posture: B           (tesht's own surface is genuinely clean -- no telemetry, no credential
                     reads, no persistent stores, tight default temp-dir permissions, localhost-
                     only HTTP binding. The two real gaps [global xtrace, undocumented cwd-over-
                     HTTP exposure] are live capabilities with no current evidence of exploitation
                     in this estate's actual usage, not confirmed-active harms.)
Remediation: B       (2 capability-first remediation entries, both cheap: a scoped-trace-or-
                     documented-warning disposition for TESHT-S1, a doc-comment update and/or a
                     --serve-dir scoping option for TESHT-S2. Both filed as tracked tasks before
                     this cycle's completion gate.)
```

## Block 8 — Remediation capabilities + verification

- Capability: a scoped or redacted trace mode for `-x`/`--trace`, or at minimum an explicit
  documented warning that `--trace` exposes all subsequent command arguments including
  credentials to stderr. Illustrative mechanism (non-binding): a limited `PS4` or subshell-scoped
  xtrace restricted to tesht's own internals, mirroring the same capability mk.bash's own
  MK-S2 remediation (mk.bash #78878) already proposed for the identical defect shape. Verification:
  confirm `--trace` no longer dumps a credential-shaped argument to stderr in a demonstration test
  run, or that a documented warning exists if scoping is rejected as disproportionate. (tesht
  #79359)

- Capability: document `tesht.StartHttpServer`'s cwd-exposure behavior explicitly in its own
  doc-comment, and/or add a `--serve-dir`-style override so a caller testing against a
  subdirectory isn't implicitly serving the whole current working directory. Illustrative
  mechanism (non-binding): an optional second argument or flag naming the directory to serve,
  defaulting to cwd for backward compatibility but making the choice explicit rather than
  implicit. Verification: confirm the doc-comment names the exposure, or that a file outside a
  scoped serve-directory is not fetchable while the server runs. (tesht #79360)
