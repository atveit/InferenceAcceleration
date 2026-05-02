# ABS Toolchain Status (Track A, 2026-05-01)

This file is the install-attempt evidence for the ABS toolchain. **No
ABS spec in this project has been simulated through `absc`** — the
toolchain is not available in the environment. All `.abs` files in this
remediation are reviewed by inspection only. Any "behavioral model"
claim in the headers is a static-text claim, not a captured run.

## Summary verdict

`absc` is **NOT INSTALLED** on this machine and was not installable in
this session via the channels attempted. ABS files are illustrative
source artifacts only. No `theory/reports/abs_runs/<file>.log` exists
because no run was performed.

## What was tried

### 1. Direct binary search

```bash
$ which absc
absc not found
$ which abs
abs not found
```

No ABS compiler in `PATH`.

### 2. Homebrew (`brew search abs`)

```bash
$ brew search abs
==> Formulae
abseil  git-absorb  goolabs  ssllabs-scan  qbs
==> Casks
abstract  cloudytabs  obs  pushplaylabs-sidekick  silicon-labs-vcp-driver
sql-tabs  streamlabs
```

None of these is the ABS compiler from
[abstools/abstools](https://github.com/abstools/abstools). The
`abs-models` formula does not exist on the default Homebrew taps and no
`abstools/abs` tap is published as of this session.

### 3. Erlang backend prerequisite

```bash
$ which erl
/opt/homebrew/bin/erl
```

The ABS Erlang backend prerequisite (`erl`) is present, but without
`absc` the source-to-Erlang compilation step has no front end.

### 4. Java prerequisite (for legacy Java backend)

```bash
$ /opt/homebrew/opt/openjdk@21/bin/java -version
openjdk version "21.0.10" 2026-01-20
OpenJDK Runtime Environment Homebrew (build 21.0.10)
```

Java 21 is available (Homebrew), but again that is a backend
prerequisite, not the front end.

### 5. Docker image (`abslang/absc`)

The `abslang/absc` Docker image was the most plausible install-free
path. In this session, `docker pull abslang/absc:latest` and
`docker images` commands hung against the Docker Desktop endpoint and
did not return evidence of a successful pull within timeout. I am
treating "Docker route" as **inconclusive** rather than verified — I
did not capture a run log proving an image is present and runnable.

### 6. Source build (`abstools/abstools` from GitHub)

Not attempted in this session. The repo's build chain (Java + Sbt +
Stack/Haskell) is sizeable and outside the scope of this remediation,
which is about *honesty*, not about standing up new toolchains.

## Decision

**Track A proceeds without `absc`.** Per `REMEDIATION_PLAN.md` Standing
Rule 1 and Standing Rule 4:

> If `absc` is NOT available, write that fact (with the exact
> `which absc` / install attempts) to `theory/reports/abs_toolchain.md`.
> Do not pretend to have run anything.

> No "this would print SUCCESS" without actually running it. If you
> change arithmetic, you can compute the new sum by hand and document
> it — that's not fabrication, that's algebra.

So:

- All claims about what an `.abs` file would print are computed by
  inspection of the source and labelled "static analysis" / "by
  inspection", never "ran and observed".
- The directory `theory/reports/abs_runs/` is intentionally empty for
  this track. If someone later installs `absc`, runs are to be captured
  there following the canonical pattern below.

## Canonical run pattern (for future use)

If `absc` becomes available:

```bash
cd /Users/amund/research/gemma4dflashpapertheory
absc --erlang theory/phase1_foundations/run/eml_ops.abs -o /tmp/abs_eml/
cd /tmp/abs_eml
gen/erl/run \
  2>&1 | tee /Users/amund/research/gemma4dflashpapertheory/theory/reports/abs_runs/eml_ops.log
```

(The exact flag is `--erlang` for the Erlang backend; the canonical
ABS docs at https://abs-models.org/ describe the harness binary at
`gen/erl/run`. This is *prescriptive*, not run.)

## What "checked" would mean here, if it were checked

A green ABS run is **simulation** of an executable model:

- It produces a trace of `println` outputs and (with `assert`s) either
  a clean exit or an `assertion failure`.
- It does **not** explore all reachable states — ABS simulation runs
  one execution of the actor schedule, not the full state space.
- It is therefore strictly weaker than a TLA+ TLC run, which is
  bounded model checking, which is strictly weaker than a Lean proof.

So even with a captured run log, claims of "verified" remain
overreach. The honest verb is "demonstrated for one schedule" or
"illustrated".

## Why these pins (would-be)

- `absc` from `abstools/abstools`: the only mainline, maintained ABS
  front end that targets both Erlang and Maude. Other forks
  (`abs-models/abstools`) are mirrors.
- Erlang backend over Maude: Erlang executes; Maude rewrites. For
  trace-style demos like ours, Erlang is the right target.
