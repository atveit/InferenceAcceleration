# ABS run logs

Captured `stdout` from running each `.abs` file in [`../abs/`](../abs/)
through the ABS Erlang backend. The run logs are the **execution
evidence** for the asserts in those files; without them, the asserts are
just text. With them, each scenario is a reproducible
sequence-of-events trace.

## Toolchain

- ABS compiler `absc`, built from source against `master` of
  [`abstools/abstools`](https://github.com/abstools/abstools)
- Apple Silicon-specific install notes:
  [`../reports/abs_toolchain.md`](../reports/abs_toolchain.md)
- Erlang/OTP 28, rebar3 3.27.0
- macOS Darwin 25.4.0 on M3 Ultra

## Headline assertions (one per file)

| Log | Source | Assertion | Result |
|---|---|---|---|
| [`eml_ops.log`](./eml_ops.log) | [`../abs/eml_ops.abs`](../abs/eml_ops.abs) | `\|sm − eml\| < 0.001` on `(p=0.4, q=0.6)` | passed: `\|diff\| = 5.349e-4` |
| [`tree_perf.log`](./tree_perf.log) | [`../abs/tree_perf.abs`](../abs/tree_perf.abs) | discrete-grid argmax of `(log B + 1) / (10 + 0.5 B)` over `B ∈ {1,2,4,8,16,32,64}` is at `B = 8` | passed: argmax is `B = 8`, throughput `≈ 0.21996` |
| [`slc_tiling.log`](./slc_tiling.log) | [`../abs/slc_tiling.abs`](../abs/slc_tiling.abs) | `occupancy ≤ maxCapacity` after every access in the LRU scenario (16 MB pinned LUT + 12 streamed 8 MB tiles + 2 re-accesses, 10-tile LRU budget) | passed: peak occupancy `96 MB`, ceiling `96 MB`, never exceeded |

## How to reproduce

Build `absc` once (full recipe with macOS gotchas in
[`../reports/abs_toolchain.md`](../reports/abs_toolchain.md)):

```bash
cd /path/to/abstools && make frontend
export PATH=$PWD/frontend/bin:$PATH
```

Then for each model:

```bash
cd ../abs
for name in eml_ops tree_perf slc_tiling; do
    rm -rf /tmp/abs_$name
    absc -e -d /tmp/abs_$name $name.abs
    /tmp/abs_$name/run > ../abs_runs/$name.log 2>&1
done
```

A passing scenario prints normally and exits 0. A failing assertion
crashes the Erlang VM with a stack trace — that's the failure signal.

## What this proves and does not prove

These are still **Tier 3 (behavioral models)** in the four-tier evidence
pyramid of the [companion blog post](https://amund.blog/g4-flashtree-formal-verification/).
Each run exhibits one specific scenario:

- one numeric pair for `eml_ops`,
- one analytic grid for `tree_perf`,
- one LRU schedule for `slc_tiling`.

A green log proves the scenario, not the property for all inputs. ABS
asserts are not Lean theorems; they are dynamic checks at one trace
through the model. Promotion to a real coverage claim would require
either a TLA+-style state-space exploration of the same model or a
property-based generator over input scenarios.
