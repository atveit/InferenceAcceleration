# Upstream patches against `abstools/abstools`

These are the patches we applied to a local clone of
[`abstools/abstools`](https://github.com/abstools/abstools) `master` to
get `absc` building cleanly on macOS / Apple Silicon / Erlang OTP 28.
They are the load-bearing dependency behind the "by execution" upgrade
of the three ABS files in [`../abs/`](../abs/) — without them, `make
frontend` produces a jar with no absmodel `.beam` files, and `absc -e`
fails at the first model with `Could not locate Runtime
file:.../<module>.beam`.

## What each patch fixes

`0001-fix-frontend-erlang-bundle-absmodel-.beam-files-in-j.patch` —
**three cumulative bugs**, one commit:

1. **macOS Gradle does not follow rebar3's `priv` symlink** in
   `_build/`, aborting downstream resource processing. New Gradle task
   `fixErlangPrivSymlink` replaces the symlink with a real directory
   before `jar` / `shadowJar` / `processTestResources` read it.
2. **rebar3 issue
   [#379](https://github.com/abstools/abstools/issues/379)** — the
   first `rebar3 compile` invocation fetches deps and exits 1 *before*
   compiling absmodel itself; the existing `ignoreExitValue = true` on
   `compileErlangBackend` masked this so deps' `.beam` files (cowboy,
   jsx) made it into the jar but absmodel's own — including
   `dpor.beam` — did not. Split into two passes: `fetchErlangDeps`
   tolerates exit 1, then `compileErlangBackend` re-runs and requires
   exit 0.
3. **`dpor.erl` uses the deprecated `slave` module**, scheduled for
   removal in OTP 31; on OTP 28 this emits a hard deprecation warning
   during compile. Migrated to the supported `peer` API
   (`peer:start_link/1` map form, `peer:stop/1`).

## How to apply

```bash
git clone --depth=1 https://github.com/abstools/abstools.git
cd abstools
git am /path/to/InferenceAcceleration/g4-flashtree-formal-verification/patches/0001-*.patch
```

Then build:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk
export PATH="$JAVA_HOME/bin:$PATH"
make clean
rm -rf frontend/build frontend/dist
make frontend     # ~37s on M3 Ultra
```

Verify the jar is correctly populated:

```bash
$ unzip -l frontend/dist/absfrontend.jar \
    | grep -cE 'absmodel/_build/default/lib/absmodel/ebin/.*\.beam'
26
$ unzip -l frontend/dist/absfrontend.jar | grep dpor.beam
   55048  02-01-1980 00:00   erlang/absmodel/_build/default/lib/absmodel/ebin/dpor.beam
```

Then [`../reports/abs_toolchain.md`](../reports/abs_toolchain.md)'s
"How the captured runs were produced" recipe runs all three ABS files
through the Erlang backend and reproduces the logs in
[`../abs_runs/`](../abs_runs/).

## Upstream status

The patches have not been submitted upstream as of the blog post date
(2026-05-02). They are kept here as the reproducibility hook for the
"Tier 3 — by execution" claim in the [companion blog
post](https://amund.blog/g4-flashtree-formal-verification/).
