# TLA+ / ABS Audit (2026-05-01)

Auditor: Claude (Opus 4.7), invoked from `/Users/amund/research/gemma4dflashpapertheory`.
Audit corpus: 3 TLA+ specs + 3 ABS specs listed in OVERVIEW.md / 20260501TheoryPlan.md.

---

## 0. Evidence Standard (read first)

**Rule applied throughout this audit: No output, no evidence.**

Per the user's reinforced instruction:

> "TLC may not have actually been run on the TLA+ specs (no logs in reports/). ABS 'verified throughput' is simulation, not proof."

For every artifact below:

- A property in the source file that has **no captured TLC log, no `MC.tla`, no `MC.cfg`,
  no `*.tlc`, no `states/` directory, no `*.out`, no `*.log`** is classified
  **WRITTEN-NOT-CHECKED**, regardless of what reports/ prose claims about it.
- A successful TLC run is **bounded model checking**, not a proof for all `N`.
  Words like "proved", "proof", "machine-checked" overstate what TLC produces.
- An ABS run is **simulation** of an executable model. It produces traces, not
  proof obligations discharged. ABS code that contains zero `assert` statements
  and is simply a `println` walk-through is **demonstration**, not even simulation
  in the verification sense.
- Both TLC and ABS are strictly **weaker** than the Lean theorem proofs in this
  same project. The blog must distinguish these tiers explicitly.

The exhaustive search for run artifacts under
`/Users/amund/research/gemma4dflashpapertheory/`:

```
find . -type f \( -name "*.log" -o -name "MC.tla" -o -name "MC.cfg" \
                -o -name "*.tlc" -o -name "states" -o -name "*.out" \
                -o -name "*.dot" \)
```

returned **zero results**. The only `.cfg` file in the entire repo is
`theory/phase4_validation/walk/non_interfere.cfg` (5 lines, shipped beside the
spec; no log of it ever being executed).

---

## 1. Toolchain status (this audit session)

| Tool                | Status | Evidence |
|---------------------|--------|----------|
| `tlc` on PATH       | Not installed | `which tlc` → "tlc not found" |
| `tla2tools.jar`     | Present at `/Users/amund/.tla/tla2tools.jar` (TLC2 v2.19, 8 Aug 2024) | Verified by running it |
| `java` (default)    | Broken — `/usr/bin/java` cannot locate JRE | `java -version` → "Unable to locate a Java Runtime" |
| `java` (Homebrew)   | OK — `/opt/homebrew/opt/openjdk@21/bin/java` (OpenJDK 21.0.10) | Used for runs below |
| `absc` (ABS compiler) | Not installed | `which absc` → not found |
| ABS Erlang backend  | `erl` present (`/opt/homebrew/bin/erl`), but no `absc` to compile to it | — |
| ABS simulation logs in repo | None | empty `find` |

I was therefore able to **run TLC** in this session (using a manually-set up
copy in `/tmp/tlc_audit/`), but **could not run any ABS spec** — there is no
ABS toolchain installed and no captured ABS simulation output anywhere in the
repo.

---

## 2. TLA+ findings

### 2.1 `theory/phase2_integration/walk/rollback.tla`

**OVERVIEW claim** (`OVERVIEW.md:28`, `20260501TheoryPlan.md:25`):
> "Rollback State Safety (TLA+) … Proof of 'No Ghost Reads' during O(1) resets."

**Properties stated** (lines from the source file):

- L49 `Spec == Init /\ [][Next]_vars` — safety-only spec, **no fairness**, so no
  liveness can be proven from this.
- L52 `NoGhostReads == \forall i \in pending_reads : i <= len`

**Properties checked?** **No.** There is no `rollback.cfg` in the repo. There
is no MC harness. There is no log. **WRITTEN-NOT-CHECKED.**

**Worse — the file as committed does not even parse.** When I attempted a TLC
run in this session, the as-shipped `rollback.tla` failed at parse time:

```
***Parse Error***
Was expecting "==== or more Module body"
Encountered "Rollback" at line 29, column 11 and token "Unsafe"
```

Two structural problems in the source:

1. **L29, L35, L42, L51** use `--` as a comment prefix
   (e.g. `-- Unsafe Rollback: Directly updates the pointer regardless of active reads`).
   TLA+ comments are `\*` (line) or `(* ... *)` (block). `--` is **not legal
   TLA+ syntax** at the module level; the parser tries to read it as the start
   of a separator line and aborts.
2. **L2** `EXTENDS Integers, Sets`. There is no standard module called `Sets`.
   The standard module is `FiniteSets`. With Sets, TLC errors:
   `Cannot find source file for module Sets imported in module rollback`.

After patching both (replacing `-- ` with `\* ` and `Sets` with `FiniteSets`)
in a working copy, TLC ran with `MaxLen = 4` and reported:

```
Model checking completed. No error has been found.
189 states generated, 31 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 9.
```

So the underlying *logic* (with the synthesized config and patched syntax) is
consistent with `NoGhostReads` over a 31-state space. But:

- The repo's actual `.tla` is **uncheckable** (parse error). Anyone reading
  OVERVIEW.md who ran `tlc rollback.tla` would get a parse error, not a proof.
- 31 distinct states at `MaxLen=4` is a **tiny** state space; this is not a
  scaling argument.
- The spec excludes `UnsafeRollback` from `Next` (L43-47), so the model
  trivially cannot violate `NoGhostReads`. The interesting comparison
  ("UnsafeRollback would violate NoGhostReads") is **not run** — only a
  hand-wavy comment at L29 mentions it. A proper safety-vs-unsafe
  refinement / counterexample run would be the meaningful artifact, and it is
  absent.

**Severity: BLOCKER** for the OVERVIEW claim "Proof of 'No Ghost Reads'":
- The file does not parse without manual fixes.
- No `.cfg` or run log was ever shipped.
- The claim of "proof" is overstated even for a fixed version: TLC at
  `MaxLen=4` is bounded model checking of a tiny finite instance, not a proof
  for unbounded `MaxLen`.

---

### 2.2 `theory/phase3_optimization/walk/dispatch.tla`

**OVERVIEW claim** (`OVERVIEW.md:29`, `20260501TheoryPlan.md:36`):
> "AMX/ANE Dispatch Safety (TLA+) … Safety proof for asynchronous NPU offloading."

**Properties stated**:

- L49 `Spec == Init /\ [][Next]_vars`
- L53 `DataIntegrity == (amx_status = "Reading" => buffer_state = "Reading")`
- L57 `NoCollision == ~(ane_status = "Writing" /\ amx_status = "Reading")`
- L61 `DeadlockFree == ~(amx_status = "Idle" /\ ane_status = "Idle" /\ buffer_state = "Empty")`

**Properties checked?** **No.** No `dispatch.cfg`, no log. **WRITTEN-NOT-CHECKED.**

**Same parse failure as `rollback.tla`**: L13, L21, L28, L36, L51, L55, L59
all use `--` for comments. The spec as committed will **not parse** under any
TLC version.

After patching (`-- ` → `\* `) and synthesizing a config:

```
Model checking completed. No error has been found.
5 states generated, 4 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 4.
```

Findings on the *logic*:

- The state space is 4 distinct states. That is small enough to verify by
  inspection. TLC adds essentially nothing — it's a 4-state finite automaton
  (Idle → ANE-Writing → Buffer-Ready → AMX-Reading → Empty). A diagram would
  carry the same evidence.
- `DeadlockFree` is **not** in the file's `INVARIANT` list anywhere. It is
  defined (L61) and labelled "(To be checked by TLC as a property)". It is
  **not actually checked** even in a synthesized config — the natural reading
  of the comment confirms the author knew this was a TODO. As written,
  `DeadlockFree` would be **falsified** by the initial state where everything
  is Idle/Empty — see `Init` at L8-11. So `DeadlockFree` as stated is
  trivially false in the very first state. This is a real bug in the spec.
- The model has no fairness assumption, so liveness cannot be proven anyway.
- The "safety" of NPU offloading in real hardware involves: cache coherence,
  IOSurface lifetime, CPU/GPU/ANE memory ordering, partial writes, error
  paths. None are modelled. The 3-variable abstraction
  `(amx_status, ane_status, buffer_state)` captures only happy-path
  request/release.

**Severity: MAJOR**:
- Parse failure as committed.
- `DeadlockFree` is malformed (false in `Init`) and was never actually checked.
- The model is so small that "TLC proved safety" is over-credit — it's a
  4-state finite check.
- Real-world NPU dispatch hazards are abstracted away. The spec proves a
  protocol skeleton, not "AMX/ANE Dispatch Safety" as a system property.

---

### 2.3 `theory/phase4_validation/walk/non_interfere.tla` (+ `.cfg`)

**OVERVIEW claim** (`OVERVIEW.md:34`, `20260501TheoryPlan.md:47`):
> "[DONE] Proof that drafter/bypass tuning cannot bias the target distribution."

**Properties stated**:

- L61 `Spec == Init /\ [][Next]_Vars /\ WF_Vars(Verify)` — has weak fairness
  on `Verify`.
- L66-68 `NonInterference ==
        Len(accepted_output) <= Len(target_model_trace)
     /\ accepted_output = SubSeq(target_model_trace, 1, Len(accepted_output))`
- L71 `Termination == <> (accepted_output = target_model_trace)`

The accompanying `non_interfere.cfg` (the only `.cfg` in the repo) sets:
```
SPECIFICATION Spec
INVARIANT NonInterference
CONSTANTS Tokens = {t1, t2}, MaxTraceLen = 5, MaxDraftLen = 3
```
Note `Termination` is **not** listed under `PROPERTY` in the cfg. So even if
TLC ran, it would only check the safety invariant, not the liveness claim.

**Properties checked?** **No log was captured.** No `.tlc`, no console output,
no states dir. The file `phase4_2_validation_critique.md:35` contains the
prose claim:

> "The model checker successfully explores the state space (within the bounds
>  defined in `.cfg`) and confirms that the safety invariant holds even under
>  adversarial drafter conditions."

This sentence has no backing log file. **WRITTEN-NOT-CHECKED in repo.**

**This audit attempted to actually run it.** The file as committed
**fails to model-check directly**:

```
Error: TLC encountered a non-enumerable quantifier bound
Seq({t1, t2}).
line 22, col 17 to line 22, col 27 of module non_interfere
```

The `Init` predicate (L20-22) writes
`\E s \in Seq(Tokens) : Len(s) \in 1..MaxTraceLen /\ target_model_trace = s`
and `DrafterPropose` (L30) writes `\E s \in Seq(Tokens) : ...`. `Seq(S)` is
the *infinite* set of all finite sequences over `S`; TLC cannot enumerate it.
**The shipped `.cfg` cannot have produced a successful TLC run** — the same
config TLC version 2.19 throws an immediate "non-enumerable quantifier bound"
error before generating any states. So `phase4_2_validation_critique.md`'s
"successfully explores the state space" is **demonstrably impossible** with
the shipped artifacts.

To get TLC to run, I created a wrapped variant `non_interfere_mc.tla` that
replaces `Seq(Tokens)` with a bounded helper
`BoundedSeq(S, N) == UNION { [1..n -> S] : n \in 0..N }`,
with `MaxTraceLen=3, MaxDraftLen=2`. Results:

```
14 initial states.
422 states generated, 252 distinct states found.
NonInterference: NO VIOLATION.
Termination: VIOLATED. Counter-example:
  State 1: <Initial predicate> accepted_output = <<>>, ...
  State 2: Stuttering.
```

Findings:

1. **`NonInterference` invariant is consistent** with the model in the bounded
   variant (252 states, no violation). This is a real but small piece of
   evidence.
2. **`Termination` does not hold even bounded.** The spec permits an initial
   state to stutter forever before any action fires. The `WF_Vars(Verify)`
   only constrains behaviors *given* `Verify` is enabled, but in the initial
   state `drafter_proposal = << >>`, `Verify` is *disabled*. There is no
   fairness on `DrafterPropose`, so the system can stutter at `Init`
   indefinitely. This contradicts the report's claim
   (`phase4_2_walk.md:30`):
   > "The `Termination` property ensures that the system eventually produces
   >  the full target trace, proving that speculative decoding does not cause
   >  infinite loops or stalls."
   That sentence is **false as a model-checker output**: TLC reports
   `Termination` violated by stuttering. The cfg also doesn't list it under
   `PROPERTY`, so the original "verification" wouldn't have caught it.
3. **`NonInterference` is structurally weaker than the OVERVIEW claim.**
   - OVERVIEW says: "drafter/bypass tuning cannot bias the **target
     distribution**."
   - Spec says: `accepted_output` is a prefix of a fixed `target_model_trace`.
   - These are different objects. The spec has no notion of probability,
     distribution, sampling, or temperature. `target_model_trace` is a single
     concrete sequence chosen non-deterministically in `Init`. The "Verifier"
     in the spec is a deterministic LCP-then-append-correction-token routine
     against that fixed trace. The drafter cannot "bias the distribution"
     because there is no distribution in the model — only a fixed string.
   - The proof being made is therefore: **"if the verifier deterministically
     overrides drafter tokens that don't match a fixed reference trace, the
     output equals a prefix of that reference trace"** — a near-tautology.
     This is fine as a *correctness sketch* of the LCP rule, but it is not a
     proof that drafter quantization cannot bias a sampling distribution.
4. **State space is small.** 252 states at `MaxTraceLen=3, MaxDraftLen=2`,
   `|Tokens|=2`. The shipped cfg's larger bounds (5, 3) might fail or take
   longer, but more importantly do not generalize. Speculative decoding
   correctness in real systems involves sampling, KV-cache state, rollback,
   and is not a finite-state property.

**Severity: MAJOR**:
- Spec as shipped + shipped cfg → `Seq(Tokens)` non-enumerable error,
  i.e. TLC **cannot have run** on the shipped artifact pair, despite the
  critique report claiming success.
- `Termination` claim is false in the bounded variant.
- The safety invariant is real but only states "deterministic verifier
  overwrites a fixed string", far weaker than "cannot bias the target
  distribution".

---

## 3. ABS findings

**Toolchain reality check.** No `absc` is installed. The `abs-models` runtime
is not present. No simulation output from any of the three `.abs` files is
checked into the repo (`find … -name "*.out" -o -name "*.log"` is empty).
The plan text (`20260501TheoryPlan.md:70`) asserts as a *success criterion*:

> "ABS: Simulated throughput meets >90% of empirical target."

This is a **goal**, not evidence. There is no run artifact backing it for any
of the three ABS files.

All three ABS files below are **WRITTEN-NOT-SIMULATED** in repo. Independent
of that, several of them are not actually verification artifacts at all —
they are `println`-driven demos.

---

### 3.1 `theory/phase1_foundations/run/eml_ops.abs`

**OVERVIEW claim** (`20260501TheoryPlan.md:15`):
> "Verified EML-to-Softmax parity model."

**What it actually does**:

- L24-36 `SoftmaxActor.compute(p, q)`: computes
  `if (p < q) res = log(p) - log(q)`, hard-codes `latency = 24`, calls
  `m!logResult("StandardSoftmax", res, 24)`.
- L38-49 `EMLActor.compute(lp, lq)`: computes
  `if (lp < lq) res = lp - lq`, hard-codes `latency = 1`, calls
  `m!logResult("EMLMinPlus", res, 1)`.
- Main block (L51-66): runs each once with `p=0.4, q=0.6, lp=-0.916, lq=-0.510`.

**There is no assertion of parity anywhere in the file.** No `assert`, no
property, no invariant. The "parity" is supposed to be inferred by the human
reading the two `println` lines and noticing the numbers are similar.

**The "cycle counts" are hard-coded constants** (24 and 1). They are not
derived from anything; they are written into the source as facts. So this
file does not "verify" cycle reduction — it **asserts** it via `println`.
The 24× claim in the plan reduces to "the author wrote 24 in one place and 1
in another."

**The `if (lp < lq) res = lp - lq` else 0 logic is also a parity bug**: in
the SoftmaxActor case, the `else` branch leaves `res = 0.0`, which
corresponds to `log(min(1, p/q)) = 0` when `p >= q` — that part is correct.
In the EMLActor, the `else` branch leaves `res = 0.0`, corresponding to
`min(0, lp - lq)` when `lp >= lq`, which is also correct. So the *logic* of
both is the right mathematical identity: `log(min(1, p/q)) = min(0, log p - log q)`.
But the file doesn't *prove* that — it just exhibits it on one numeric pair.
A real parity proof would be in Lean (and `phase1_foundations/walk/tq_topo.lean`
or similar may do it; not in audit scope).

**Severity: MAJOR** (relative to the "Verified EML-to-Softmax parity" claim):
- No simulation output captured.
- No assertion in the source — the file is a `println` demo.
- "Cycle reduction" is a hard-coded constant, not measured or derived.
- Parity is one numeric example, not a property.

---

### 3.2 `theory/phase2_integration/run/tree_perf.abs`

**OVERVIEW claim** (`20260501TheoryPlan.md:26`):
> "Verified B-budget routing efficiency."

**What it actually does** (L23-42):

```
mal      = log(b) + 1.0
latency  = 10.0 + b * 0.5
throughput = mal / latency
```

for `b ∈ {1, 2, 4, 8, 16, 32, 64}`, then `println`s each tuple.

**This is a closed-form formula, not a verification.** The "verified
optimality" reduces to:

> The author wrote a model `MAL(B) = log(B) + 1, lat(B) = 10 + 0.5B`,
> tabulated `MAL/lat` at 7 points, and asserts the maximum identifies the
> "optimal B".

This is a **plot generator**, not a model checker, not a proof. There is no
property asserted. No measurement is taken from the real system. No assertion
that this curve matches measured G4-FlashTree behavior. The `// based on
empirical logs` comment at L29 is the only link to reality, and it is just a
comment.

If the goal is "DDTree budget tuning", the right artifact is the empirical
benchmark sweep, not an ABS file that hardcodes its own assumed model and
prints the result of evaluating that model.

**Severity: MAJOR**:
- "Verified" is the wrong word; this is a parameter sweep over an *assumed*
  analytic model.
- No simulation log captured. No `assert`. The file's only effect is
  `println`s.
- No connection to the real DDTree implementation or benchmarks.

---

### 3.3 `theory/phase3_optimization/crawl/slc_tiling.abs`

**OVERVIEW claim** (`OVERVIEW.md:30`, `20260501TheoryPlan.md:35`):
> "SLC Tiling Bounds (ABS) … Proven 96MB residency for KV-cache blocks."

**What it actually does**:

- `SLCManager(maxCapacity)` (L11-45): a basic LRU-less cache that just
  appends new resources and tracks `occupancy = sum of sizes`. On miss it
  prints `MISS` / `LOAD` and either prints occupancy or `DRAM SPILL`.
- Main (L47-79): inserts a 16 MB LUT, then 12 tiles × 8 MB = 96 MB, then
  re-accesses tile 0, then prints final occupancy, then prints
  `SUCCESS: Simulation stayed within SLC bounds.` iff `occupancy <= 96`.

**Computed total occupancy of the scenario**:
`16 (LUT) + 12 × 8 (tiles) = 16 + 96 = 112 MB`. Capacity is `96 MB`.

So when this scenario is run, `occupancy = 112 > 96` and the file's
`if (occupancy > maxCapacity) println("DRAM SPILL ...")` branch fires. The
final block prints `WARNING: DRAM Spill detected during simulation.`, **not**
`SUCCESS: Simulation stayed within SLC bounds.`

In other words: **the ABS file as written, if simulated, demonstrates a DRAM
spill, not 96 MB residency.** It is the opposite of the "proven 96 MB
residency" claim in OVERVIEW.

I cannot run it (no `absc`), but the arithmetic is doable by hand: 16 + 12×8 = 112.

**Additional structural issues**:

- There is no eviction policy. The "cache" is append-only. Nothing in the
  file models the SLC's actual eviction behavior (LRU, set-associative,
  hardware-controlled). So even with a working simulation, the result would
  not be "SLC residency bound" — it would be "if you load X MB into a list,
  the list contains X MB".
- The model has no notion of access frequency, working set, or tile reuse
  pattern. The 1024-token / 24 MB working-set claim from
  `Gemma4_SLC_Optimizations.md` (referenced in root `CLAUDE.md §6.3`) is
  **not** modelled here.
- "Proven" is again the wrong verb; ABS at this level is execution, not
  proof.

**Severity: BLOCKER**:
- The scenario-as-written (16 MB LUT + 12×8 MB tiles = 112 MB) **exceeds**
  the 96 MB capacity. The file, if executed, would print `WARNING: DRAM
  Spill detected during simulation.` This is the opposite of the "proven
  96 MB residency" claim.
- The cache model has no eviction; it cannot be a model of SLC residency.
- No simulation log captured.

---

## 4. Cross-cutting findings

1. **No TLC, no ABS run artifacts in the repo.** A repo-wide search for
   `*.log`, `MC.tla`, `MC.cfg`, `*.tlc`, `states/`, `*.out`, `*.dot` returns
   empty. Only `non_interfere.cfg` exists.
2. **The shipped `non_interfere.tla` + `non_interfere.cfg` cannot have been
   model-checked successfully**, because `Seq(Tokens)` triggers TLC's
   non-enumerable-quantifier-bound error immediately. Any prose claim that
   TLC ran on it is contradicted by trying to actually run TLC on it. The
   author may have had a different working version locally, but what is
   committed cannot have produced a green run.
3. **`rollback.tla` and `dispatch.tla` do not parse as committed.** They use
   `-- ` line comments, which are not legal TLA+. `rollback.tla` also imports
   a non-existent module `Sets`. There is no shipped `.cfg` for either.
4. **Even with shim configs and patched syntax**, the state spaces TLC
   covers in this audit (4 states for dispatch, 31 for rollback, 252 for
   bounded non_interfere) are tiny finite instances. They are not "proofs"
   in any general sense.
5. **The ABS files contain no `assert` statements.** They are `println`
   demos with hard-coded numeric models. The word "verify" in the plan and
   reports is not earned by these files.
6. **`slc_tiling.abs`'s scenario contradicts its own claim** — the loads
   sum to 112 MB into a 96 MB cache. The spec, on execution, would report
   spill, not residency.
7. **`tree_perf.abs`'s "MAL = log(B)+1, latency = 10+0.5B"** is an analytic
   guess written into the source; it is not a model derived from the actual
   DDTree implementation, nor compared to the empirical benchmarks. The
   "verified optimal B" reduces to evaluating that analytic expression at
   7 points.
8. **`eml_ops.abs`'s "cycle counts" (24 vs 1)** are hard-coded literals.
   The file contains no logic that computes cycle counts; the speedup
   claim is what was typed into the file, not what was measured or proved.
9. **The reports under `theory/reports/`** repeatedly use the words
   "Verified", "VERIFIED", "model checker successfully explores" without
   any backing log artifact and, for `non_interfere.tla`, in direct
   contradiction to the actual TLC behavior on the shipped files.
10. **Lean proofs are not in audit scope here**, but they are the only
    artifacts in this project that produce reproducible verification
    output via `lake build`. Any claim of "machine-checked" should be
    qualified to apply to the Lean files only.

---

## 5. Verdict on blog / OVERVIEW claims

| OVERVIEW claim | Source | Verdict |
|---|---|---|
| "Proof of 'No Ghost Reads' during O(1) resets" | `rollback.tla` | **WRITTEN-NOT-CHECKED** + UNCHECKABLE-AS-SHIPPED. File doesn't parse (`-- ` comments, missing `Sets` module). After fixes, TLC at MaxLen=4 covers 31 states; the property holds in that finite slice but `UnsafeRollback` is excluded from `Next`, so the comparison the OVERVIEW implies (safe vs unsafe rollback) is not actually run. |
| "Safety proof for asynchronous NPU offloading" | `dispatch.tla` | **WRITTEN-NOT-CHECKED** + OVERSTATED. File doesn't parse as committed. Underlying state space is 4 states. `DeadlockFree` (defined L61, never `INVARIANT`-listed in any cfg) would actually be **falsified** by `Init`. |
| "Proof that drafter/bypass tuning cannot bias the target distribution" | `non_interfere.tla` | **WRITTEN-NOT-CHECKED** as committed (TLC fails on `Seq(Tokens)`) + OVERSTATED. The bounded variant safety property holds; the *liveness* property (`Termination`) is **violated** in the bounded variant. The spec also has no notion of "distribution"; it proves prefix-equality against a fixed string. |
| "Verified EML-to-Softmax parity model" | `eml_ops.abs` | **WRITTEN-NOT-SIMULATED.** File is a `println` demo with hard-coded cycle counts. No assertion, no simulation log. |
| "Verified B-budget routing efficiency" | `tree_perf.abs` | **WRITTEN-NOT-SIMULATED.** File evaluates a hard-coded analytic curve `MAL/(10+0.5B)` at 7 points. No tie-back to measurements; no assertion; no log. |
| "Proven 96MB residency for KV-cache blocks" | `slc_tiling.abs` | **CONTRADICTED BY THE FILE'S OWN ARITHMETIC.** 16 MB LUT + 12 × 8 MB tiles = 112 MB, exceeds the 96 MB capacity. The model has no eviction policy. |

---

## 6. Recommended blog disclaimers

The blog draft must add language equivalent to the following before any of
the above claims are stated. These are concrete sentences:

1. **On TLA+ in this project:** "The TLA+ specifications in this work were
   model-checked with TLC under bounded constants
   (e.g. `MaxLen = 4`, `MaxTraceLen = 5`). TLC produces *bounded model
   checking* results for finite instances; it does not constitute a proof
   for unbounded inputs. Where we say 'verified' we mean 'no counter-example
   found within these bounds.'"
2. **On `rollback.tla` specifically:** "The TLA+ rollback model demonstrates
   that the safe-rollback rule (waiting for active reads beyond the new
   length) preserves the `NoGhostReads` invariant in 31 reachable states at
   `MaxLen = 4`. We did not exhibit a TLC counter-example for the unsafe
   variant in this artifact; the comparison is by inspection. The shipped
   `.tla` requires comment-syntax fixes before TLC will parse it."
3. **On `dispatch.tla` specifically:** "The dispatch model is a 4-state
   finite automaton over `(amx_status, ane_status, buffer_state)`. It does
   not model cache coherence, IOSurface lifetimes, partial writes, or error
   paths. The `DeadlockFree` predicate as written is false in the initial
   state and was not used as an invariant in any model-checker run."
4. **On `non_interfere.tla` specifically:** "The non-interference TLA+ model
   shows that an LCP-then-append-correction-token verifier rule, run against
   a fixed `target_model_trace`, produces an `accepted_output` that is
   always a prefix of `target_model_trace`. It does **not** prove that
   drafter quantization preserves the target *distribution* — there is no
   sampling or distribution in the model. The `Termination` property does
   not hold in the bounded model (initial-state stuttering); the strong
   guarantee is safety, not liveness."
5. **On the ABS files:** "The three ABS files in this project are
   *executable models* in the ABS surface language. They are demonstrations
   and analytic plotters: `eml_ops.abs` exhibits the Softmax↔Min-Plus
   identity on one numeric pair with hand-coded cycle latencies (24 vs 1);
   `tree_perf.abs` evaluates a closed-form analytic curve at seven `B`
   values; `slc_tiling.abs` walks a no-eviction cache through a fixed load
   sequence. None contain `assert` statements or formal properties. We did
   not run them through the ABS toolchain; the toolchain (`absc`) is not
   present in our environment, and no simulation output is checked into the
   repo. These files are *illustrative*, not verification artifacts."
6. **On `slc_tiling.abs` specifically:** "The scenario in `slc_tiling.abs`
   loads 16 MB (LUT) + 12 × 8 MB (KV tiles) = 112 MB into a 96 MB cache.
   On execution the model would report a 16 MB DRAM spill, not 96 MB
   residency. The OVERVIEW phrasing 'Proven 96MB residency' is incorrect
   for the artifact as committed."
7. **On the project as a whole:** "The strongest verification artifacts in
   this project are the Lean 4 proofs (`*.lean`), which are mechanically
   re-checkable via `lake build`. The TLA+ and ABS artifacts are weaker:
   TLA+ provides bounded model-checking evidence (and three of the shipped
   files require fixes before TLC will run them), and ABS provides
   illustrative simulations (and we have not actually run them). The
   phrase 'machine-checked blueprint' from the OVERVIEW should be
   restricted to the Lean components."

---

## 7. Appendix — TLC runs performed in this audit session

All runs used `/Users/amund/.tla/tla2tools.jar` (TLC2 v2.19, 8 Aug 2024)
under OpenJDK 21.0.10. Working copies in `/tmp/tlc_audit/`. **None of these
runs were on the unmodified shipped files**; each required at minimum a
synthesized `.cfg`. The shipped TLA+ artifacts cannot be model-checked
without the fixes noted below.

| File (working copy) | Modifications from repo | Result |
|---|---|---|
| `rollback.tla` (as-is) | none | **PARSE ERROR** — `--` comments, missing `Sets` module |
| `rollback.tla` (patched) | `-- ` → `\* `; `Sets` → `FiniteSets`; synthesized cfg `MaxLen=4`, INVARIANT `NoGhostReads` | OK. 189/31 states. `NoGhostReads` not violated. |
| `dispatch.tla` (as-is) | none | **PARSE ERROR** — `--` comments |
| `dispatch.tla` (patched) | `-- ` → `\* `; synthesized cfg INVARIANTS `DataIntegrity NoCollision` | OK. 5/4 states. Both invariants hold. |
| `non_interfere.tla` (as-is, shipped cfg) | none | **TLC ERROR** — non-enumerable quantifier bound `Seq({t1,t2})` |
| `non_interfere_mc.tla` (wrapped) | replaced `Seq(Tokens)` with `BoundedSeq(S,N) == UNION { [1..n -> S] : n \in 0..N }`; cfg `MaxTraceLen=3, MaxDraftLen=2` | 422/252 states. `NonInterference` holds. `Termination` **VIOLATED** (initial-state stuttering). |

ABS runs: **none performed** — `absc` is not installed in this environment.
