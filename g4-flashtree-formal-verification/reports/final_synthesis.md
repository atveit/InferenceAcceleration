# Final Synthesis Report: G4-FlashTree Theoretical Framework

**REWRITTEN 2026-05-01 by Track R post-remediation. Original (pre-audit)
contents — which used "Zero Hallucination," "Total Semantic
Subsumption," "Proven 96 MB residency," and "ALL PHASES VERIFIED"
language — preserved in git history.**

This file is the project-level synthesis. It must reflect what
*actually* survived the two parallel audits
([`audit_lean.md`](audit_lean.md), [`audit_tla_abs.md`](audit_tla_abs.md))
and the three-track remediation pass (L, T, A). For the canonical
tier-classified evidence layout, read [`OVERVIEW.md`](../../OVERVIEW.md).

## 1. Executive Summary

The G4-FlashTree theoretical work consists of **4 mechanically
rechecked Lean theorems**, **4 TLA+ properties confirmed under bounded
TLC runs** (one of which is a load-bearing safety counter-example),
and **3 ABS behavioral models without captured runs** (the `absc`
toolchain is not installed in this environment).

Two artifacts originally framed as headline proofs were **deleted** in
remediation as vacuous: the "zero-copy IOSurfaces" Lean file
(record-projection identity) and the "total semantic subsumption" Lean
file (modus-ponens specialization of a universal quantifier). The
"zero-hallucination" claim is therefore no longer a Tier-1 deliverable
of this project. If it appears anywhere downstream (blog, paper) it
must be Tier 4 (engineering prose) backed by acceptance-rate /
benchmark logs, not by a Lean theorem.

This synthesis does *not* close any "theoretical loop". The honest
framing is: a smaller, tier-classified core of formal evidence, with
explicit gaps to the runtime system documented as deferred findings.

## 2. Phase 4 outcomes (revised)

| Sub-Phase | Tier | Artifact | What is and is not claimed |
| :--- | :--- | :--- | :--- |
| **4.1 Crawl** | **T1** | `theory/G4FlashTreeTheory/MaskEquiv.lean` | Theorem (Lean, lake-build-green): tree-mask softmax-attention output equals path-attention output at every query position over `ℝ`. Strengthened from the original sum-of-Nat model. **Does not** transfer to fp16 floats. See [`lean_remediation_notes.md`](lean_remediation_notes.md) §L5. |
| **4.2 Walk** | **T2** | `theory/phase4_validation/walk/non_interfere.tla` + `non_interfere.cfg` | Bounded model check (TLC2 v2.19, `Tokens={t1,t2}, MaxTraceLen=3, MaxDraftLen=2`, 252 distinct states) of `NonInterference` (safety only). Original `Seq(Tokens)` was non-enumerable; bounded helper added in remediation. `Termination` was **dropped** (initial-state stuttering). The spec proves prefix-equality of `accepted_output` against a fixed reference trace; **there is no probability or distribution in the model**. See [`tla_remediation_notes.md`](tla_remediation_notes.md) §T3 and [`phase4_2_validation_critique.md`](phase4_2_validation_critique.md) (rewritten as a post-mortem). |
| **4.3 Run** | **DELETED** | `theory/phase4_validation/run/subsumption.lean` | The original theorem was modus ponens. No probability, no Gemma model, no verifier algorithm. Deleted in remediation. The "zero-hallucination" claim is not a Tier-1 deliverable of this project. See `lean_remediation_notes.md` §L6. |

## 3. Project-wide outcomes (revised)

### A. Mathematical results (Tier 1, Lean, lake-build-green)

Toolchain: Lean 4.30.0-rc2 + Mathlib v4.30.0-rc2. Build evidence:
[`lake_build.log`](lake_build.log) (`Build completed successfully
(1980 jobs)`, exit 0). Surviving theorems:

- **`RopeId.lean`** — over any commutative ring, the standard 2D
  rotation `(c, s)` with `c² + s² = 1` preserves the dot product
  `v.x·w.x + v.y·w.y`. *Not* p-RoPE-specific (the "p" plays no role)
  and *not* a floating-point result. Sanity instance at `ℝ` with
  `Real.cos`, `Real.sin`.
- **`TQTopo.lean`** — for any real inner-product space and any
  `T : V → V` with `‖T z − z‖ ≤ η ‖z‖`, the inner product is
  preserved up to `2η ‖x‖ ‖y‖ + η² ‖x‖ ‖y‖`. Generic
  Lipschitz-perturbation bound; does **not** model TurboQuant's
  Hadamard rotation, per-block scale, or `O(d^{-1/2})` distortion.
- **`AttnIso.lean`** — sliding-window softmax-attention is
  zero-leakage at position `t` when scores and values agree inside
  the window at `t`. Includes the normalizer.
- **`MaskEquiv.lean`** — see Phase 4.1 above.

### B. Concurrent-systems results (Tier 2, TLA+, TLC2 v2.19)

Toolchain pinned in [`tla_toolchain.md`](tla_toolchain.md). All four
spec/property pairs have committed run logs in
[`tlc_runs/`](tlc_runs/). Each is bounded model checking, not a proof
for unbounded `N`.

- **`rollback.tla`** Safe `Spec` at `MaxLen=4`: 31 distinct states;
  `NoGhostReads` not violated. ([`rollback.log`](tlc_runs/rollback.log))
- **`rollback.tla`** `UnsafeSpec` at `MaxLen=4`: 4-state
  counter-example showing `pending_reads = {1}` while `len = 0`.
  This is the load-bearing artifact for the SafeRollback guard.
  ([`rollback_unsafe.log`](tlc_runs/rollback_unsafe.log))
- **`dispatch.tla`**: 4 distinct states (no constants);
  `DataIntegrity`, `NoCollision` (safety), and
  `Liveness == <>(buffer_state /= "Empty")` under `WF_vars(Next)`.
  Borderline-vanity: a 4-state finite automaton; TLC adds little
  over a hand-drawn diagram. The original `DeadlockFree` predicate
  was malformed (false in `Init`) and was removed.
  ([`dispatch.log`](tlc_runs/dispatch.log))
- **`non_interfere.tla`**: 252 distinct states at the stated bounds;
  see Phase 4.2 above.

### C. Behavioral models (Tier 3, ABS, *not* run)

`absc` is not installed. [`abs_toolchain.md`](abs_toolchain.md)
records the install attempts. [`abs_runs/`](abs_runs/) is intentionally
empty. All three files are inspected, not executed.

- **`eml_ops.abs`** — algebraic identity demo on one numeric pair;
  `assert |sm − eml| < 1e-3`. Cycle constants are placeholders.
- **`tree_perf.abs`** — closed-form throughput curve at 7 grid
  points; `assert optimalB == 8`. Analytic guesses, not measurements.
- **`slc_tiling.abs`** — pinned-LUT + LRU-tile cache; `assert
  occupancy <= maxCapacity`. By inspection, max is 96 MB. Original
  scenario contradicted itself (16 + 12×8 = 112 MB > 96 MB cap);
  fixed in remediation. **LRU is a fiction relative to the
  hardware-managed M3 Ultra SLC.**

### D. Engineering prose (Tier 4, unverified in this project)

The following are real claims about the runtime system but are *not*
in the formal bundle: zero-copy IOSurface handoffs, ANE residency,
wall-clock decode/prefill numbers, LUT FP4→FP16 SLC speedup,
engine-concurrency overlap. Their evidence belongs in `powermetrics`,
Instruments traces, and benchmark logs. CLAUDE.md §9 standards apply.

## 4. Epistemic conclusion (revised)

The Why-Why-Why analysis (per
[`prompts/WhyWhyWhyForFormalLanguage.prompt`](../../prompts/WhyWhyWhyForFormalLanguage.prompt))
of this project's pre-remediation state surfaced the dominant failure
mode: **claims of "verified" / "machine-checked blueprint" / "zero
hallucination" propagated downstream from artifacts that were either
non-compiling, unparseable, or vacuous.** The remediation's response
was to ship a *smaller* honest core rather than rescue every original
deliverable. Two Lean files were deleted; one TLA+ liveness property
was dropped; three ABS files were demoted from "Verified" to
"behavioral model"; one ABS scenario's arithmetic was corrected.

What remains is a partial result. The Tier 1 evidence proves
correctness properties of *abstracted* operators (CommRing dot
product, generic η-Lipschitz bound, ℝ-valued softmax). The Tier 2
evidence proves *protocol* safety in tiny finite slices (4–252
states). The Tier 3 evidence is illustrative, not a verification.
None of this evidence transfers automatically to bf16/fp16 Gemma 4
running on M3 Ultra; the bridge from `ℝ` to IEEE-754 and from
protocol skeleton to actual hardware is **engineering prose**, not
formal evidence.

The honest takeaway is not "we proved G4-FlashTree is safe." It is:
"we proved an interface-level skeleton, model-checked a few protocol
slices, and documented the gaps to the running system." Anyone citing
this project must respect the tier boundaries.

## 5. What this synthesis is NOT

- It is **not** a "ALL PHASES VERIFIED" claim. The pre-remediation
  version made that claim; the audits showed it was unsupported.
- It is **not** a guarantee of "Zero Hallucination" or "Total
  Semantic Subsumption". Those were the headlines of two deleted
  Lean files.
- It is **not** a proof of "96 MB residency". That was contradicted
  by the `slc_tiling.abs` arithmetic; the demoted Tier-3 demo
  documents what survived.
- It is **not** a proof of "non-interference of drafter on target
  distribution". The TLA+ spec proves prefix-equality against a
  fixed sequence; there is no distribution in the model.
- It is **not** reproducible at unbounded `N`. Bounded model checking
  covers tiny finite instances.
