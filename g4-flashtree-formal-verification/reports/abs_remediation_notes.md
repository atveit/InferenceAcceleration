# ABS Remediation Notes (Track A)

Owner: agent-A
Plan: `REMEDIATION_PLAN.md` Track A (A0–A4)
Toolchain status: see `abs_toolchain.md` — `absc` not installed; no
runs captured.

This file is appended to in timestamped iterations. Do not batch.

---

## 2026-05-01 17:00 — A0: Toolchain attempt

- `which absc` → not found.
- `brew search abs` → no `abs-models`/`absc` formula in default taps.
- `docker pull abslang/absc:latest` → command did not complete in
  this session (Docker Desktop endpoint hung). Not a verified install,
  not a verified failure either; treated as inconclusive.
- Source build from `abstools/abstools` — not attempted.

**Decision:** proceed with file-level remediation (A1–A4) **without
`absc`**. All claims about what a file would print are static-analysis
claims. `theory/reports/abs_runs/` stays empty. See `abs_toolchain.md`.

---

## 2026-05-01 17:15 — A1 design: `slc_tiling.abs`

The audit caught a real bug: the scenario writes `16 + 12*8 = 112 MB`
into a `96 MB` cache. With the file's no-eviction `if (occupancy >
maxCapacity)` branch, the file, **if** simulated, prints
`WARNING: DRAM Spill detected during simulation.`, **not** `SUCCESS`.

Two routes were on the table per `REMEDIATION_PLAN.md`:

(a) shrink the working set so it fits.
(b) add LRU eviction.

I picked **(b)**. Reasoning: (a) would just confirm the trivial
identity "if you load less than 96 MB into a 96-MB list, the list has
less than 96 MB". That's not a claim about *residency under reuse*,
which is the SLC's actual interesting property. (b) at least models
"steady-state resident set ≤ capacity even when total flow > capacity",
which is what a real cache demonstrates.

Concrete (b) design:

- `LUT` (16 MB) is **pinned** — not LRU-evictable. This matches the
  `Gemma4_SLC_Optimizations.md` pattern: a 256-entry FP4→FP16 LUT is
  meant to be SLC-resident continuously.
- KV tiles (8 MB each) are LRU-evictable. With 16 MB pinned, the tile
  budget is `96 - 16 = 80 MB → 10 tiles`.
- The scenario streams **12 tiles** through. Tiles 0 and 1 are the
  oldest by the time tile 11 arrives, so they get evicted to make
  room. Re-accessing tile 0 should now miss (correctly), then evict
  the next-oldest. Re-accessing tile 11 should hit.
- After every `access`, ABS `assert occupancy <= maxCapacity;` is
  invoked. This is the property the file should constrain. The whole
  point of the redesign is that this assert *cannot* fire under the
  scenario.

**What this demonstrates:** under cyclic / streaming tile access with
LRU, occupancy never exceeds capacity.

**What this does NOT prove:**
- That the M3 Ultra SLC actually uses LRU. (It does not — the SLC is a
  hardware-managed last-level cache with set-associative replacement
  closer to LRU/PLRU than true LRU. The file is therefore
  *behaviorally illustrative*, not a hardware model.)
- That the tile size and count match the real Gemma 4 working set.
  `Gemma4_SLC_Optimizations.md` (per root `CLAUDE.md §6.3`) names a
  ~24 MB working set for a 1024-token window — so a real model would
  use 8 KV tiles × 3 MB each, not 12 × 8 MB. The 8 MB / 12-tile choice
  is sized to make the eviction story visible, not to reproduce
  measured numbers. Source comments must say so.
- That occupancy is the right summary statistic. A real residency
  argument would talk about hit rate under a measured access trace,
  not max-occupancy under a synthetic one.

---

## 2026-05-01 17:30 — A2 design: `eml_ops.abs`

Two changes:

1. **Add an `assert` connecting Softmax and EML numerically.** The
   identity is `log(min(1, p/q)) = min(0, log p − log q)`. The current
   file computes both sides on one numeric pair and prints them. After
   the fix, `MainActor` collects both results into shared monitor
   state, then does `assert |sm_result − eml_result| < epsilon;` after
   both computations have logged. This binds the parity claim into a
   property that fails the simulation if the numbers diverge.

2. **Acknowledge `latency = 24` and `latency = 1` are placeholder
   constants, not measured.** Add a header comment block. Do not
   change the numbers — they're a stand-in for "ALU cost of two `log`
   plus a subtract" vs "ALU cost of one subtract", and the *ratio*,
   not the absolute, is what the file is illustrating. Adjusting the
   numbers without a measurement would be more dishonest than calling
   them placeholders.

**What this demonstrates:** for one (p, q) pair, the two computations
agree to `epsilon`.

**What this does NOT prove:**
- Parity for all (p, q) — that's a Lean theorem, not an ABS one.
  See `phase1_foundations/walk/tq_topo.lean` (Track L scope).
- Any cycle-cost claim at all. The latencies are typed in by hand.

---

## 2026-05-01 17:45 — A3 design: `tree_perf.abs`

The current file evaluates the closed form `MAL/(10+0.5B)` at seven
`B` values and `println`s them. There is no actual maximum check.

Change: after the sweep, compare the throughput at each `B` and
`assert` that the maximum lies at the `B` where the analytic curve
peaks (algebra: `argmax (log B + 1)/(10 + 0.5 B)` over
`{1,2,4,8,16,32,64}`). I will compute that argmax by hand below and
hard-code it as the predicted optimum, with the `assert` checking that
the simulation's measured argmax equals it.

Closed form: let `f(B) = (ln B + 1) / (10 + 0.5 B)`.

| B  | ln B   | num    | den   | f(B)    |
|----|--------|--------|-------|---------|
| 1  | 0.0000 | 1.0000 | 10.5  | 0.09524 |
| 2  | 0.6931 | 1.6931 | 11.0  | 0.15392 |
| 4  | 1.3863 | 2.3863 | 12.0  | 0.19886 |
| 8  | 2.0794 | 3.0794 | 14.0  | 0.21996 |
| 16 | 2.7726 | 3.7726 | 18.0  | 0.20959 |
| 32 | 3.4657 | 4.4657 | 26.0  | 0.17176 |
| 64 | 4.1589 | 5.1589 | 42.0  | 0.12283 |

Argmax over the discrete grid is at `B = 8` with `f = 0.21996`. The
continuous maximum (set `df/dB = 0`) is at `B = 2(1 - ln B*)`-style
solution which lands near `B ≈ 7-9`; the grid puts the peak at 8.

So the `assert` is `optimal_b = 8`. (And the comment must say "this is
on a closed-form curve, not a measurement.")

**What this demonstrates:** at seven sample points, the analytic
expression peaks at 8.

**What this does NOT prove:**
- Anything about the real DDTree decoder. The MAL and latency curves
  are guesses. The `// based on empirical logs` comment in the
  original is unsupported by any committed log; I am leaving the
  numbers but stripping the "empirical" claim.
- That `B = 8` is the right operating point in production. That's a
  measurement question, and ABS is not the place for it.

---

## 2026-05-01 17:50 — A4: relabeling

Each `.abs` header gets:
- old: `Verified ...`
- new: `Behavioral model — illustrates ... ; does NOT verify ...; not
  run (see abs_toolchain.md)`.

The `20260501TheoryPlan.md` and `OVERVIEW.md` rows for ABS are flagged
for Track R but not edited here.

Files affected:
- `eml_ops.abs:3-4`
- `tree_perf.abs:3-4`
- `slc_tiling.abs:3-4`

---

## 2026-05-01 18:00 — A1 implementation: `slc_tiling.abs`

Rewrote the file to add LRU eviction with a pinned LUT. Tile budget
= 80 MB ÷ 8 MB = 10. Streamed 12 tiles → tile 0, 1 evicted. Re-access
tile 0 → MISS (load + evict). Re-access tile 11 → HIT. After every
access, `assert occupancy <= maxCapacity;`.

By inspection (not by run): occupancy after each step:

```
LUT pinned                      → 16
+ tile 0..9 (10 tiles)          → 16 + 80 = 96  ← capacity
+ tile 10 (evict tile 0)        → 16 + 80 = 96
+ tile 11 (evict tile 1)        → 16 + 80 = 96
re-access tile 0 (MISS, evict 2)→ 16 + 80 = 96
re-access tile 11 (HIT)         → 16 + 80 = 96
```

So `occupancy ≤ 96` throughout. The `assert` does not fire on this
scenario.

**Self-critique against `absCritique.prompt`:**

- Layer 1 (modeling choices): the `cachedResources` list models a tiny
  fixed-size LRU; ABS's actor model is overkill here. *Could* be a
  single sequential function. Why ABS? Honestly: because it's the
  Track-A toolchain. This file does not benefit from concurrency.
  Vanity risk: medium.
- Layer 4 (invariant): `occupancy <= maxCapacity` is the *one*
  property worth asserting and is not invented for proof scaffolding.
  Naturalness: high. If removed, the file's only safety claim is gone
  — so the assert carries weight.
- Layer 7 (model vs reality): the M3 Ultra SLC is hardware-managed,
  set-associative, and not strictly LRU. This file simulates LRU at
  block granularity, with no notion of cache lines, ways, or
  prefetcher behavior. Calling this "SLC residency" is generous.
- Layer 9 (epistemic value): does the file teach anything execution
  doesn't? Marginal. The same property is provable on paper in two
  lines: pinned + LRU + tile budget = 80 MB, max occupancy is reached
  and held, never exceeded. The simulation only *demonstrates* that.
  It does not *explain* why.
- Layer 10 (anti-vanity): without the assert, this file is a
  println-walker. With the assert, it is a single-trace residency
  demo. Calling it "Proven 96 MB residency" — as the original
  OVERVIEW does — would still be wrong; the honest verb is
  "demonstrated under one synthetic LRU schedule."

Deferred finding: a much stronger artifact would be a TLA+ spec of the
LRU residency invariant, model-checked across all scheduling choices.
That is Track T's territory, not A's. Recording for Track R.

---

## 2026-05-01 18:15 — A2 implementation: `eml_ops.abs`

Restructured `MainActor` block to:

1. Run both `compute` calls.
2. Aggregate results into the `Monitor` object (state-collecting).
3. After both are logged, query the monitor for both results.
4. `assert |sm_result - eml_result| < 1.0e-3;`

For p=0.4, q=0.6:
- StandardSoftmax: `log(0.4) − log(0.6) = -0.9163 − (-0.5108) = -0.4055`
- EML: `−0.916 − (−0.510) = −0.406`

Difference: `0.0005` (within the 1e-3 tolerance, accounting for the
3-significant-figure inputs `lp=-0.916, lq=-0.510`).

Header now reads:

```
// Phase 1.3 Run: EML Algebra, behavioral model.
// Illustrates the algebraic identity
//     log(min(1, p/q)) = min(0, log p - log q)
// on one numeric pair (p=0.4, q=0.6). The `latency = 24` and
// `latency = 1` constants are PLACEHOLDERS and are not measured;
// they encode the ratio "two log + sub vs one sub", not absolute
// cycle counts. This file is illustrative, not a verification of
// parity for all (p,q) and not a measurement of cycle cost.
```

**Self-critique:**

- The assert binds parity to one input pair. Real parity is Lean
  territory (`tq_topo.lean`). So the file remains illustrative.
- The `Monitor` wiring is heavier than necessary: ABS doesn't have a
  clean way to *return* a value from an async actor call before
  asserting on it without `await`. The simplest honest fix is to
  compute both expressions in the main block (sequentially) and assert
  there, with the actors used only for the latency-logging side-show.
  I'll go that route in the implementation: keep the actor pretense
  for the cycle-cost narrative, but compute the numerical comparison
  in the main `{ }` block where assertion ordering is trivial.
- Vanity risk: low after the change. The assert is honest about what
  it constrains.

---

## 2026-05-01 18:30 — A3 implementation: `tree_perf.abs`

After the sweep loop, track the running max throughput and the `B` at
which it occurred. After the loop, `assert optimal_b == 8;`. Also
record `assert max_throughput > 0.21 && max_throughput < 0.22;` as a
sanity check against my hand-computed `0.21996`.

Header now reads:

```
// Phase 2.3 Run: DDTree Budget, behavioral model.
// Illustrates a closed-form throughput curve
//     thr(B) = (log B + 1) / (10 + 0.5 B)
// evaluated at B in {1,2,4,8,16,32,64}. The MAL and latency models
// are ANALYTIC GUESSES, not derived from a measured DDTree. The
// `// based on empirical logs` comment in earlier revisions was
// unsupported and has been removed. This file is illustrative, not a
// measurement.
```

**Self-critique:**

- The `assert optimal_b == 8` constrains: "the closed-form curve, on
  this discrete grid, peaks at B=8". That is a property of the
  *formula*, not of any system. Removing it leaves a println walker.
  Adding it makes the file fail-fast if anyone tampers with the
  formula's coefficients. Marginally useful.
- Vanity risk: medium. The peak-at-B=8 number gets cited in the blog;
  whatever the blog says about it must add "on this analytic curve".
- Deferred finding: the *real* artifact for B-tuning is a benchmark
  sweep across actual prompts. That artifact lives in
  `bench_hybrid.py` in the sibling `gemma4joinedwithdflash/` tree, not
  in ABS.

---

## 2026-05-01 18:45 — Final critique pass

Re-read `prompts/absCritique.prompt` and `prompts/absWhy-why-why.prompt`
against the three updated files. Top three deferred findings to
surface to Track R:

1. **`tree_perf.abs` does not connect to `bench_hybrid.py`.** The
   honest replacement is to ingest the measured throughput-vs-B
   table from `bench_hybrid.py` and have ABS assert against *those*
   numbers, not against the closed form. Out of Track A scope; flag
   as a future deliverable.

2. **`slc_tiling.abs`'s LRU is a fiction.** The M3 Ultra SLC is
   hardware-managed; we don't know its policy from this codebase.
   The right artifact is `powermetrics` / Instruments-based residency
   evidence under a real Gemma 4 prefill. ABS at this level cannot
   produce that. Track R should not let "Proven 96 MB residency"
   stand in any document.

3. **`eml_ops.abs` carries no cycle-cost evidence at all.** The 24/1
   constants are written in by hand. If the blog wants to claim a
   cycle-count win, the source must be a Metal kernel
   microbenchmark or hardware counters, not an ABS literal. Track R
   should sever the file's headline claim from the cycle-cost
   narrative — they are independent.

All three of these are documented in source comments in the updated
files, but the Tier-3 "illustrated" framing only goes so far. They
need to surface in `OVERVIEW.md` / `20260501TheoryPlan.md`.

---

## 2026-05-01 19:00 — Track A final summary

Deliverables shipped:

| Deliverable | Path | Status |
|---|---|---|
| Toolchain attempt log | `theory/reports/abs_toolchain.md` | Written. `absc` confirmed NOT installed. Docker route inconclusive. |
| `slc_tiling.abs` rewrite | `theory/phase3_optimization/crawl/slc_tiling.abs` | Pinned LUT + LRU eviction. `assert occupancy <= maxCapacity` after every access. Arithmetic by inspection: 16 + 10*8 = 96 MB, never exceeds 96. |
| `eml_ops.abs` patch | `theory/phase1_foundations/run/eml_ops.abs` | `assert delta < 0.001` on the parity identity. Cycle constants explicitly labeled placeholders in header. |
| `tree_perf.abs` patch | `theory/phase2_integration/run/tree_perf.abs` | `assert optimalB == 8` against the closed-form argmax. Header says "analytic guess" not "empirical". |
| Track-A notes | `theory/reports/abs_remediation_notes.md` | This file. |
| `abs_runs/` placeholder | `theory/reports/abs_runs/README.md` | Documents intentional emptiness. |

**Track-R flagging (do not edit yourself):**

The following rows in `20260501TheoryPlan.md` and the corresponding
"Improved Result" cells in `OVERVIEW.md` are now contradicted by the
files they cite, and need updating by Track R:

- "Verified EML-to-Softmax parity model" → demote to "Behavioral
  model: parity identity demonstrated on one numeric pair; cycle
  ratio is a placeholder, not measured."
- "Verified B-budget routing efficiency" → demote to "Behavioral
  model: closed-form throughput curve peaks at B=8 on the discrete
  grid; not a measurement of the real DDTree."
- "Proven 96MB residency for KV-cache blocks" → demote to "Behavioral
  model: under one synthetic LRU schedule with a pinned LUT and a
  10-tile budget, resident set never exceeds 96 MB. Not an M3 Ultra
  SLC hardware model and not measured residency."

**Confirmation:** `slc_tiling.abs` is no longer self-contradictory.
The arithmetic now satisfies the assertion: 16 (pinned LUT) + 10
tiles × 8 MB (LRU budget) = 96 MB exactly; the streaming of tiles
11..0 never grows the resident set above 96 MB because new tiles
evict the LRU before insertion. The `assert occupancy <= maxCapacity`
after every `access` is the property that constrains this.

**Top 3 deferred findings** (also listed in 18:45 entry):

1. `tree_perf.abs` should ingest `bench_hybrid.py` measurements rather
   than assert against a hand-written analytic curve.
2. `slc_tiling.abs`'s LRU is a fiction relative to the hardware-managed
   M3 Ultra SLC; replacing it with a TLA+ residency invariant or with
   a `powermetrics`/Instruments measurement is the next honesty step.
3. `eml_ops.abs`'s `latency = 24` and `latency = 1` literals carry no
   measurement weight; if a cycle-cost claim is to appear in the
   blog, it must come from a Metal microbenchmark, not from this
   file.
