# ABS Toolchain Status (updated 2026-05-02)

> **Status as of 2026-05-02:** `absc` is **installed and working** on this
> machine, built from the `abstools/abstools` `master` branch on
> Apple Silicon. All three `.abs` files in [`../abs/`](../abs/) compile
> through the Erlang backend, run via `rebar3`, and produce captured
> stdout logs at [`../abs_runs/`](../abs_runs/) with their assertions
> passing. The earlier "not installed; inspection only" status (preserved
> for context at the bottom of this file) no longer applies.

## How the toolchain was put together

### 1. Prerequisites (Homebrew)

```bash
brew install openjdk      # 25.0.2 — Gradle toolchain wants Java 25
brew install erlang       # 28.x — runtime for the Erlang backend
brew install rebar3       # 3.27 — drives the per-model Erlang build
```

The Gradle build of `abstools/abstools` `master` requires Java 25; the
older Homebrew `openjdk@21` works for TLC but not for Gradle here. Set
`JAVA_HOME=/opt/homebrew/opt/openjdk` (i.e. the unversioned formula) and
prepend its `bin/` to `PATH` before invoking `make`.

### 2. Source build of `absc`

```bash
git clone --depth=1 https://github.com/abstools/abstools.git
cd abstools

export JAVA_HOME=/opt/homebrew/opt/openjdk
export PATH="$JAVA_HOME/bin:$PATH"

make frontend       # ~30s with hot Gradle daemon; ~3 min cold
```

This produces `frontend/bin/absc` and `frontend/dist/absfrontend.jar`.

### 3. Build the Erlang runtime support and bundle into the jar

Upstream `master` (commit before this work) shipped **without** the
precompiled Erlang `.beam` files for the runtime support library
(`absmodel`), and the Gradle build silently produced jars with no
absmodel `.beam`s for two compounding reasons:

1. **macOS symlink incompatibility.** rebar3 creates a `priv` symlink
   inside `_build/`; Gradle's `processResources` task on macOS refuses
   to follow it across the source/build boundary and aborts.
2. **rebar3 issue [#379](https://github.com/abstools/abstools/issues/379).**
   On a fresh checkout, the *first* `rebar3 compile` invocation fetches
   deps and exits 1 *before* compiling absmodel itself. The Gradle task
   set `ignoreExitValue = true` and gave up at that point, so the deps'
   `.beam` files (cowboy, jsx, etc.) were bundled into the jar but
   absmodel's own — including `dpor.beam` — were not.

We patched `frontend/build.gradle` to fix both:

- Added a `fixErlangPrivSymlink` task that replaces the rebar3 symlink
  with a real directory before downstream tasks read it.
- Split `compileErlangBackend` into two passes (`fetchErlangDeps`
  ignores exit on the first, `compileErlangBackend` requires exit 0 on
  the second). This guarantees absmodel actually compiles.
- Wired `jar`, `shadowJar`, and `processTestResources` to depend on
  `fixErlangPrivSymlink` so the `.beam` files land in the jar.

We also migrated `frontend/src/main/resources/erlang/absmodel/src/dpor.erl`
from the deprecated `slave` module (scheduled for removal in OTP 31) to
the supported `peer` API, so the build runs cleanly on Erlang/OTP 28.

The patch is checked in at
[`../patches/0001-fix-frontend-erlang-bundle-absmodel-.beam-files-in-j.patch`](../patches/);
see [`../patches/README.md`](../patches/README.md) for `git am`
instructions.

With those patches in place, the build is a single command from a clean
checkout:

```bash
cd /path/to/abstools
make clean
rm -rf frontend/build frontend/dist
make frontend     # ~37s on M3 Ultra
```

The resulting `frontend/dist/absfrontend.jar` contains 26 absmodel
`.beam` files (verified via `unzip -l`), and `absc -e -d /tmp/foo bar.abs`
succeeds out of the box.

### 4. Verify install

```bash
$ which absc
/path/to/abstools/frontend/bin/absc

$ absc --version
ABS Tool Suite version unknown
Built from git tree unknown-not_compiled_in_git_repo-unknown
```

(The `unknown` strings are because the build was not from a tagged
release; functionality is unaffected.)

## How the captured runs were produced

```bash
cd /path/to/InferenceAcceleration/g4-flashtree-formal-verification

for name in eml_ops tree_perf slc_tiling; do
    rm -rf /tmp/abs_$name
    absc -e -d /tmp/abs_$name abs/$name.abs
    /tmp/abs_$name/run > abs_runs/$name.log 2>&1
done
```

All three exit cleanly. Their assertions pass. See
[`../abs_runs/README.md`](../abs_runs/README.md) for the per-file
headline-assertion table.

## What this changes vs. the audit-pass

The Track-A audit verdict for the `.abs` files was *behavioral model
written but never executed*. With `absc` installed and run logs
captured:

- The `assert` lines in each file are now dynamically checked, not just
  text in the source. Failure would crash the Erlang VM with a stack
  trace — so a green log is real evidence.
- The Tier-3 framing in the [companion blog
  post](https://amund.blog/g4-flashtree-formal-verification/) is
  promoted from "assertions hold by inspection only" to "assertions hold
  on this scenario, by execution; logs in `abs_runs/`".
- Tier-3 is still Tier-3. ABS simulation runs **one** schedule, not the
  full state space. It is strictly weaker than a TLA+ bounded
  model-check (Tier 2) and a Lean theorem (Tier 1). The blog's "what
  formal methods can't prove" section still applies.

## Notes specific to Apple Silicon (macOS, M3 Ultra here)

The `master` branch's Gradle build assumes Java 25 toolchain
auto-detection. The Homebrew unversioned `openjdk` formula provides
exactly that; the older `openjdk@21` formula does not. If you have only
the `@21` formula, the build fails at `Cannot find a Java installation
... matching: {languageVersion=25}`. Either install the unversioned
`openjdk` or edit `frontend/build.gradle` line 27 to drop the
`JavaLanguageVersion.of(25)` toolchain pin (substitute 21).

The symlink fix in step 3(b) is also Apple-Silicon / macOS-specific —
on Linux the symlink works, but on macOS Gradle's
`processResources` task refuses to follow it.

---

## Original "not installed" status (preserved for context — superseded)

> The text below is the Track-A audit-pass record from 2026-05-01. It
> documents the state at the time the original audit ran. It is kept
> here so the audit trail is reproducible from `git show` of an earlier
> revision. The current state is "installed" (above).

The previous file recorded:

- `which absc` → not found.
- Homebrew formulae searched: `abseil`, `git-absorb`, `goolabs`,
  `ssllabs-scan`, `qbs`. None is `absc`.
- Erlang `erl` was present at `/opt/homebrew/bin/erl`.
- Java 21 was present via `openjdk@21` (worked for TLC; not
  sufficient for the `abstools/abstools` Gradle build).
- The `abslang/absc` Docker image pull was inconclusive in that
  session; Docker Desktop endpoint was unresponsive.
- Source build was deferred as out-of-scope at that time.

Decision recorded then: "Track A proceeds without `absc`." All
`.abs` claims were stamped "static analysis / by inspection" and the
`abs_runs/` directory was intentionally empty.

That decision was reversed in the 2026-05-02 follow-up after a
working source build proved feasible.
