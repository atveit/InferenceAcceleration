# Lean Remediation Notes — Track L

Owner: agent-L. Plan: `theory/reports/REMEDIATION_PLAN.md` Track L.
Audit input: `theory/reports/audit_lean.md`.

## Convention

- Every iteration gets a date-stamped section.
- Each substantive file edit gets a self-critique paragraph using
  `prompts/lean4critique.prompt` and `prompts/lean4why-why-why.prompt`.
- Build logs land in `theory/reports/lake_build.log` (final) and
  `theory/reports/lean_runs/<file>.log` (per-iteration probes).

## Project layout decision

**Decision:** Place `lakefile.toml` and `lean-toolchain` at the **repo
root** (`/Users/amund/research/gemma4dflashpapertheory/`) and put the
Lean source under `theory/G4FlashTreeTheory/`. Reasons:

1. `lake` resolves `srcDir` relative to the lakefile and prefers a
   single Lean library; trying to point Lake at the existing
   `theory/phase{1..4}_*/{crawl,walk,run}/*.lean` layout is hostile to
   Lean's module-naming rules (lowercase + underscores in path
   components, `phase1_foundations` is not a legal module path
   component).
2. Re-homing the surviving files makes the deletions of `zerocopy.lean`
   and `subsumption.lean` clean and explicit in the git diff.
3. Toolchain `v4.30.0-rc2` is reused from the sibling project
   `/Users/amund/research/lean/`, which already has a built Mathlib at
   that revision (Mathlib commit `5450b53e`). This avoids a
   ~1-hour Mathlib rebuild and gives us a known-good pin.

## 2026-05-01 — L0 bootstrap

### Iteration 1: lakefile + lean-toolchain

- Wrote `/Users/amund/research/gemma4dflashpapertheory/lean-toolchain`
  pinned to `leanprover/lean4:v4.30.0-rc2`.
- Wrote `/Users/amund/research/gemma4dflashpapertheory/lakefile.toml`
  requiring Mathlib at the same `v4.30.0-rc2` rev.
- Source root: `theory/`, library name: `G4FlashTreeTheory`.
- Initial four placeholder modules under `theory/G4FlashTreeTheory/`
  for `RopeId`, `TQTopo`, `AttnIso`, `MaskEquiv`. Umbrella file
  `theory/G4FlashTreeTheory.lean` re-exports them.

### Iteration 2: `lake update`

- Command: `lake update`
- Result: cloned Mathlib v4.30.0-rc2 (commit `5450b53e`) and 8
  transitive packages. Pulled 8294 cached oleans from Azure cache
  in 33 s. No build of Mathlib needed.
- Log: `theory/reports/lean_runs/lake_update_1.log`.

### Iteration 3: bootstrap `lake build`

- Command: `lake build`
- Result: `Build completed successfully (1902 jobs)`. The four stub
  modules each compiled in ~4 s on top of cached Mathlib.
- Log: `theory/reports/lean_runs/lake_build_bootstrap.log`.

This proves the toolchain is reproducible: anyone with `elan`
installed can clone the repo, run `lake update && lake build`, and
get a green build in ~5 min (most of which is Azure cache download).

## 2026-05-01 — L5 (MaskEquiv) — strengthen to softmax level

**Plan:** Keep the original `ancestor_le` / `causal_soundness`
content (genuine proofs) and *add* a real-valued softmax-level
statement that closes the audit's MAJOR-overstatement finding.

### Iteration 1

- Wrote `theory/G4FlashTreeTheory/MaskEquiv.lean` with:
  - `Tree`, `is_ancestor`, `ancestor_le` (kept from original).
  - `ancestor_eq_path` (set-level, kept from original).
  - `causal_soundness_nat` (kept from original).
  - **New:** `listSum`, `listSum_filter_eq_mul_indicator` — a
    real-valued list-sum and the indicator-equivalence lemma.
  - **New:** `treeDenom`, `treeNumer`, `pathDenom`, `pathNumer`
    over `ℝ` using `Real.exp`.
  - **New headline theorems:** `tree_eq_path_denom`,
    `tree_eq_path_numer`, `tree_eq_path_softmax` (output equality
    given nonzero denominator), `tree_eq_path_softmax_total`
    (unconditional output equality, with `pathDenom_pos` proving
    denominator strictly positive via self-ancestor + `exp_pos`).
- Build error: imported a non-existent `Mathlib.Algebra.BigOperators.Group.List`.
  Log: `theory/reports/lean_runs/maskequiv_1.log`.

### Iteration 2

- Removed the bad import.
- Build error: `treeDenom`/etc are noncomputable because they use
  `Real.exp`. Lean's compiler flagged this. Also two `simp` linter
  warnings about an unused `List.filter_cons` arg.
  Log: `theory/reports/lean_runs/maskequiv_2.log`.

### Iteration 3

- Added `noncomputable` to the four `def`s involving `Real.exp`.
- Cleaned the unused `simp` arg.
- Renamed unused hypothesis `h` to `_h` in `tree_eq_path_softmax`
  (it is documentary — division-by-zero never actually happens
  thanks to `pathDenom_pos`).
- Build green.
  Log: `theory/reports/lean_runs/maskequiv_3.log`.

### Self-critique (lean4critique + lean4why-why-why)

- *Layer 1 (surface code).* Tactic style is direct: `induction l`,
  `by_cases`, `simp [h, ih]`. No tactic hidden behind aesop or
  decide-magic. Reads top-to-bottom as Lakatos-style: define types,
  prove indicator-equivalence, apply to two specific instantiations
  (denom and numer).
- *Layer 2 (proof-as-program).* `tree_eq_path_denom` is morally a
  one-liner: `rw [listSum_filter_eq_mul_indicator]`. The "real" work
  is the lemma `listSum_filter_eq_mul_indicator` itself, which is a
  genuine list induction. So the headline theorems are
  *applications* of one substantive list-induction lemma; that
  lemma is not a `simp` triviality.
- *Layer 4 (mathematical content).* The audit's MAJOR finding was
  that the tree-mask vs path-mask claim was set-theoretic
  (filter-redundancy), not numerical. The new theorems prove the
  **softmax-output equality**: at any query position `i`, the
  tree-attention output (numerator/denominator both restricted to
  ancestors via mask) equals the path-attention output (numerator
  and denominator both summed only over the ancestor list). Same
  number, both as elements of `ℝ`. That is the content the audit
  asked for.
- *Layer 6 (epistemic value).* Without this proof, an honest reader
  could not be sure the tree-mask softmax actually matches the
  sequential softmax — the obvious worry is that masking zero
  inside the sum but *not* the denominator would make the softmax
  outputs differ. The proof shows that as long as both numerator
  and denominator use the same indicator, the equality holds.
  This is non-vanity content.
- *Layer 7 (anti-vanity).* Could `tree_eq_path_softmax_total` be
  closed by `simp` or `decide`? No — it requires the indicator
  rewrite, the inductive list-sum lemma, and the positivity
  argument. None of these are decidable.
- *Layer 9 (failure modes / hidden assumptions).* The proof is in
  `ℝ`. In bf16/fp16, `exp` saturates and `+` is not associative;
  so this is exact in `ℝ` and *approximate* in float. The doc
  comment states this. `pathDenom_pos` uses `Real.exp_pos`, which
  fails for "exp" of `+∞` (saturation); this is a known IEEE-754
  caveat and not closed here.

### Deferred findings on L5

1. *Float-arithmetic transfer.* The proof says nothing about
   IEEE-754 fp16 softmax (which is what Gemma 4 actually runs).
   Closing that requires a fixed-point analysis, which is out of
   scope.
2. *Score-function equality on ancestors not used.* The
   path-vs-tree equality holds trivially because both sides use
   the *same* `score`. A stronger statement would compare two
   different score functions that agree on ancestors — that is the
   `causal_soundness` flavour. We keep `causal_soundness_nat` for
   the integer case but did not extend to the real case. Deferred.
3. *Tree topology.* The `Tree` carries only `parent : Nat → Nat`
   with `parent i < i`. This is enough for ancestry but does not
   capture branching factor, depth bounds, or the "speculative
   verification tree" structure of FlashTree. Real G4-FlashTree
   trees have additional invariants (capacity, fan-out) that are
   not relevant here but worth flagging.

## 2026-05-01 — L1 (RopeId) — discharge `sorry` via Mathlib `ring`

### Iteration 1

- Wrote `theory/G4FlashTreeTheory/RopeId.lean` using
  `Mathlib.Algebra.Ring.Basic` and `Mathlib.Tactic.Ring`.
- Replaced the bespoke `IsCommRing` with Mathlib's `CommRing`.
- Proved `rotation_preserves_dot` using
  `linear_combination (v.x * w.x + v.y * w.y) * h`. The previous
  file's `sorry` is now a one-line algebraic identity: the
  Pythagorean factor `cosθ * cosθ + sinθ * sinθ = 1` enters as a
  linear-combination certificate, and `ring_nf` normalises the
  rest.
- Added `pRoPE` definition that is *honest* about the audit's
  finding: the algebraic theorem is the classical 2D rotation
  identity; the "p" of p-RoPE plays no role in this math.
- Added an `example` instantiation at `R = ℝ` and `cos_fn = Real.cos`,
  `sin_fn = Real.sin`, citing `Real.sin_sq_add_cos_sq` to discharge
  the Pythagorean hypothesis. (Sanity instance, not a separate
  theorem.)
- Build green.
  Log: `theory/reports/lean_runs/ropeid_1.log`.

### Self-critique

- *Layer 4.* The audit's BLOCKER finding (`sorry` in
  `rotation_is_orthogonal`) is closed: `linear_combination` produces
  an explicit ring certificate, no `sorry` remains.
- *Layer 7 (anti-vanity).* The proof is short. Is it vanity? No —
  the identity is non-trivial without `ring`: by hand it requires
  expanding 8 monomials and grouping. The human insight is "use
  the Pythagorean identity as a linear-combination weight"; `ring`
  handles the bookkeeping. So the difficulty is conceptual, not
  encoding. Acceptable.
- *Layer 5 (motivation).* The doc comment is explicit: this is the
  generic 2D rotation lemma, not a p-RoPE-specific fact, and it
  does not transfer to floats. So the file is not overstated — it
  proves what it states, and what it states is not what the audit
  flagged as overstated ("p-RoPE Rotational Identity" framing).

### Deferred findings on L1

1. *p-RoPE specificity.* The "p" (proportional frequency-scaling λ)
   is unused. The identity proven is the standard 2D rotation
   identity. The blog must not claim "p-RoPE rotational identity";
   "rotation preserves dot product" is the honest framing.
2. *Float transfer.* Same as everywhere: proven over `CommRing R`,
   not over `Float`/`Float16`. Deferred.

## 2026-05-01 — L3 (AttnIso) — fix syntax + softmax

### Iteration 1

- Wrote `theory/G4FlashTreeTheory/AttnIso.lean` using
  `Mathlib.Data.List.Range` and `Mathlib.Analysis.SpecialFunctions.Exp`.
- Replaced `lambda` with `fun` (Lean 4 syntax) — original parse
  errors gone.
- Switched the model from "unweighted integer sum" to softmax over
  `ℝ`: defined `swaDenom`, `swaNumer`, `swaAttn` (= numer/denom).
- Proved `swa_zero_leakage_softmax`: if two `(score, value)` pairs
  agree on every position with `swaMask t · W = true`, the softmax
  outputs agree.
- Proved `swa_independent_of_distant_past`: perturbing one position
  outside the window has zero effect on the output.
- Build green on first try.
  Log: `theory/reports/lean_runs/attniso_1.log`.

### Self-critique

- *Layer 2 (proof-as-program).* The headline `swa_zero_leakage_softmax`
  uses two applications of `listSum_indicator_congr`. That lemma
  is the load-bearing inductive content. Honest.
- *Layer 7.* Could be auto-closed by `simp` if Mathlib happened to
  have `listSum_indicator_congr` already; it does not, so we proved
  it directly. Difficulty is real.
- *Layer 9.* The doc comment lists three *unproven* items: the
  SWA/global *interaction*, the Q/K/V projection, and IEEE-754
  softmax. None of these are claimed. Honest scope.
- The `score` function is `Nat → ℝ`. There is no QK-as-bilinear-form
  structure; we treat scores as a black box. This is a deliberate
  abstraction — strengthens generality, weakens domain specificity.

### Deferred findings on L3

1. *SWA/global interaction.* The original "SWA / Global Boundary"
   claim was about how the 5-of-6 SWA pattern interleaves with one
   global layer. We prove only the SWA half. The full claim is
   deferred — likely needs a model of layer composition.
2. *Q/K/V structure.* Scores are abstract `Nat → ℝ`. The fact that
   real Gemma 4 computes `score j = (Q · K_j) / sqrt(d)` is not
   modeled. Deferred.

## 2026-05-01 — L2 (TQTopo) — Mathlib InnerProductSpace + scaled bound

### Iteration 1

- Wrote `theory/G4FlashTreeTheory/TQTopo.lean` using
  `Mathlib.Analysis.InnerProductSpace.Basic`. Replaced bespoke
  `IsOrderedRing`, the `def abs := sorry`, and the missing-`Sub`
  errors entirely.
- Theorem `tq_homomorphism_bound`: given `T : V → V` with
  `‖T z − z‖ ≤ η · ‖z‖`, prove
  `|⟨x, y⟩ − ⟨T x, T y⟩| ≤ 2η ‖x‖ ‖y‖ + η² ‖x‖ ‖y‖`.
- Build error: used inner-product notation `⟨x, y⟩_ℝ` but Mathlib's
  scoped notation is `⟪x, y⟫_ℝ` (double angle brackets).
  Log: `theory/reports/lean_runs/tqtopo_1.log`.

### Iteration 2

- `sed`-replaced single-angle to double-angle notation.
- New error: `linarith` cannot close the triangle-inequality
  combination step on its own.
  Log: `theory/reports/lean_runs/tqtopo_2.log`.

### Iteration 3

- Made the triangle-inequality step explicit by introducing two
  `abs_add` instances and letting `linarith` finish.
- New error: `abs_add` is not the right Mathlib name; it is
  `abs_add_le`.
  Log: `theory/reports/lean_runs/tqtopo_3.log`.

### Iteration 4

- Replaced `abs_add` with `abs_add_le` (sed). Build green.
  Log: `theory/reports/lean_runs/tqtopo_4.log`.

### Self-critique

- *Layer 4 (math content).* The original `error_bound η x y := η`
  was wrong: a constant bound for all `x, y` cannot hold once you
  scale `x` or `y`. The corrected `errorBound η x y := 2η‖x‖‖y‖
  + η²‖x‖‖y‖` does scale correctly and matches what Cauchy–Schwarz
  produces. This is the substantive correction.
- *Layer 7 (anti-vanity).* Could this be `nlinarith`'d in one
  line? No — `nlinarith` cannot synthesise the inner-product
  expansion. The proof requires `inner_add_left/right` rewrites,
  three Cauchy–Schwarz applications, the Lipschitz hypothesis, and
  a triangle-inequality combination. Honest content.
- *Layer 9 (hidden assumptions).* The η ≥ 0 hypothesis is in scope
  (parameter) but **never used** in the proof. Mathlib's
  `mul_le_mul` etc. derive sign info from `norm_nonneg`. So `0 ≤ η`
  is decorative; the bound holds regardless. This is fine but
  worth noting — we could drop it and the proof still goes through.
  We keep it for readability.

### Deferred findings on L2

1. *No TurboQuant content.* The theorem is generic in `T`. The
   actual TurboQuant algorithm (Hadamard, per-block scale,
   `O(d^{-1/2})` distortion) is not modeled. The `η` bound is an
   interface; what supplies that bound for actual TurboQuant on
   Gemma 4 KV-cache vectors is unproven. Deferred.
2. *No probability.* The `O(d^{-1/2})` distortion bound is
   probabilistic over the random Hadamard rotation. We prove a
   worst-case Cauchy–Schwarz bound, not a high-probability bound.
   Deferred.
3. *Float transfer.* Same caveat as everywhere. The inner product
   in `ℝ` is exact; in fp16 it is not. Deferred.

## 2026-05-01 — L4 (zerocopy) — DELETED

### Decision

Per Track L plan and audit: the original `zerocopy.lean` proved a
record-projection tautology (`transfer u1 u2 surface).region.address
= surface.region.address` by definition of `transfer`). It does not
model Apple Silicon IOSurfaces, ANE/AMX driver state, page tables,
or DMA. There is no honest path to a real "zero-copy" theorem in
Lean without an OS / hardware model that nobody has time to build
in this remediation.

### Action

- Deleted `theory/phase3_optimization/run/zerocopy.lean`.
- The blog (when it is written) must cover "zero-copy" as
  engineering prose backed by `powermetrics` / IOSurface trace
  evidence, **not** as a Lean proof.

### Self-critique

This is the right call. Keeping a relabeled "behavioral model"
Lean file would still mislead — readers see `theorem` and trust it.
Better to not ship it.

## 2026-05-01 — L6 (subsumption) — DELETED

### Decision

Per plan and audit: the original `subsumption.lean` proved
`(∀ p, IsPrefix p s → D p) → D s` instantiated at `p := s`. This is
modus ponens applied to a universal quantifier. It contained no
probability measure, no model of Gemma 4, no model of a verifier
algorithm, no model of "hallucination." The "zero-hallucination"
blog claim is **not** supported by this artifact and the artifact
is misleading because the names (`Drafter`, `GemmaDistribution`)
suggest content the proof does not have.

The plan offered an *optional* replacement using Mathlib's
`MeasureTheory`. We did not attempt it: a real probability-space
proof of speculative-decoding subsumption would require a
nontrivial formal model of token sampling, drafter distribution,
and verifier acceptance — far outside the remediation scope. Honest
deletion beats a partial measure-theoretic stub.

### Action

- Deleted `theory/phase4_validation/run/subsumption.lean`.
- The blog (when written) must:
  - either drop the "zero-hallucination" framing, or
  - back it with engineering evidence (acceptance-rate logs,
    end-to-end MMLU/HumanEval comparison vs vanilla Gemma 4) and
    label it Tier 3 / Tier 4 — *not* Tier 1.

### Self-critique

Same reasoning as L4: keeping the file relabeled would still
mislead. Deletion is correct.

## 2026-05-01 — phase-path stubs

For L1/L2/L3/L5 the original file paths
(`theory/phase{1,2}_*/{crawl,walk}/<file>.lean`) were rewritten to
short doc-only stubs that point readers to the new `theory/G4FlashTreeTheory/`
modules. These stubs are **not** part of the lake build (lakefile's
`srcDir = "theory"` only resolves the `G4FlashTreeTheory` library
root and its submodules). They exist to preserve git history and
to redirect anyone who looks up the audit's filenames.

Reason for not deleting: surgical changes principle. The audit
specifically named these files, and someone following the audit
trail should land somewhere informative.

## Final summary (2026-05-01)

### `lake build` status

```
$ lake build
Build completed successfully (1980 jobs).
EXIT: 0
```

Full final log: `theory/reports/lake_build.log`.

### Surviving Lean files

| File | What it proves (plain English) |
|---|---|
| `theory/G4FlashTreeTheory/RopeId.lean` | Over any commutative ring, the standard 2D rotation `(c, s)` with `c² + s² = 1` preserves the dot product `v.x·w.x + v.y·w.y`. Sanity-instantiated at `ℝ` with `Real.cos`, `Real.sin`. *Not* a p-RoPE-specific fact and *not* a floating-point fact. |
| `theory/G4FlashTreeTheory/TQTopo.lean` | For any real inner-product space and any (not necessarily linear) `T : V → V` with `‖T z − z‖ ≤ η ‖z‖`, the inner product is preserved up to `2η‖x‖‖y‖ + η²‖x‖‖y‖`. Generic Lipschitz-perturbation bound; not TurboQuant-specific. |
| `theory/G4FlashTreeTheory/AttnIso.lean` | Sliding-window softmax-attention is *zero-leakage*: if scores and values agree inside the window at position `t`, the SWA softmax output at `t` agrees. Includes the normalizer (denominator), unlike the original `Nat`-sum proof. |
| `theory/G4FlashTreeTheory/MaskEquiv.lean` | The original ancestor-list equivalence is preserved, *plus* a softmax-level statement: tree-mask softmax-attention output equals path-attention output at every query position. The denominator is shown strictly positive via the self-ancestor + `Real.exp_pos`. |

### Deleted Lean files

| File | Reason |
|---|---|
| `theory/phase3_optimization/run/zerocopy.lean` | Vacuous: proved a record-projection identity. No model of Apple Silicon IOSurfaces, drivers, DMA, or cache coherence. Honest deletion per plan L4. |
| `theory/phase4_validation/run/subsumption.lean` | Modus ponens dressed in LLM vocabulary. No probability, no Gemma model, no sampling, no verifier algorithm. Honest deletion per plan L6. |

The original L1/L2/L3/L5 files at their phase paths now contain
only redirect-stub comments pointing to the new `G4FlashTreeTheory/`
modules.

### Top deferred findings (gap to runtime)

1. **Float-arithmetic transfer.** *Every* surviving theorem is
   stated over `ℝ` or a commutative ring. Real Gemma 4 runs in
   bf16/fp16. None of these proofs transfer to IEEE-754 directly:
   floats are not a commutative ring (no associativity, denormals,
   saturation), and softmax in fp16 saturates `exp`. Closing this
   gap requires either (a) a separate fixed-point analysis showing
   backward-stable error bounds, or (b) a Mathlib-style formal
   float model — neither is in scope. **The blog must say so
   explicitly.**

2. **Generic over `T`, generic over scores.** TQTopo proves a
   generic `‖T z − z‖ ≤ η‖z‖` bound and *says nothing* about the
   actual TurboQuant Hadamard-rotation algorithm. AttnIso treats
   scores as `Nat → ℝ` and *says nothing* about Q/K projection.
   So Tier-1 evidence here is for *interfaces*, not for the
   specific runtime kernels. Anyone claiming "we proved TurboQuant
   is sound on Gemma 4" is overstating; we proved that *any* η-
   Lipschitz quantizer is sound up to a Cauchy–Schwarz bound.

3. **No connection to `powermetrics` or wall-clock.** No proof in
   the surviving bundle relates a Lean theorem to a measurement on
   actual M3 Ultra hardware. Per CLAUDE.md §9: every speed/power
   claim must come from a wall-clock log. The Lean tier (Tier 1)
   provides *correctness* properties of abstracted operators; it
   does *not* provide any performance or hardware-residency
   evidence. The blog must visibly partition.

