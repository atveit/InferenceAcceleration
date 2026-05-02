# Lean 4 Audit (2026-05-01)

## Evidence Standard

Per coordinator reinforcement: **No output, no evidence.** A theorem is
"verified" only if `lean <file>` (or `lake build`) prints zero errors with
the verbatim output captured in this file. Source-only readability does not
imply build success. In addition:

- Every `sorry` and `admit` is a hole. A theorem whose proof body is closed
  but which depends transitively on a `sorry` in a hypothesis-class lemma,
  an axiom-introducing definition, or an upstream lemma is **not proven** —
  it is a conditional claim shaped like a theorem.
- Every project-introduced `axiom` (as opposed to standard Mathlib axioms)
  is an unverified assumption and must be surfaced.
- A theorem whose conclusion reduces to `True`, `0 = 0`, or a tautology over
  trivially-equal record fields is **VACUOUS**, not supporting evidence for
  a substantive blog claim.
- `noncomputable`, `Classical.choice`, assumed `Decidable` instances, or
  `opaque` declarations are flagged when present.

## Toolchain status

```
$ export PATH="$HOME/.elan/bin:$PATH" && lean --version
Lean (version 4.29.1, arm64-apple-darwin24.6.0,
 commit f72c35b3f637c8c6571d353742168ab66cc22c00, Release)

$ lake --version
Lake version 5.0.0-src+f72c35b (Lean version 4.29.1)
```

**No `lakefile.lean`, `lakefile.toml`, or `lean-toolchain` exists in the
repo.** `find /Users/amund/research/gemma4dflashpapertheory -name 'lakefile*' -o -name 'lean-toolchain'`
returns nothing. Therefore `lake build` is not the appropriate invocation;
each file was checked individually with `lean <file>` from the repo root.
The toolchain that auto-installed via elan when lean/lake were first invoked
is Lean 4.29.1 — *not* the toolchain the proofs were written against (which
the project does not pin). This is itself a finding: builds are not
reproducible.

### Per-file `lean <file>` invocation, verbatim

```
$ lean theory/phase1_foundations/crawl/rope_id.lean
theory/phase1_foundations/crawl/rope_id.lean:43:8: warning: declaration uses `sorry`
EXIT: 0

$ lean theory/phase1_foundations/walk/tq_topo.lean
theory/phase1_foundations/walk/tq_topo.lean:27:4: warning: declaration uses `sorry`
theory/phase1_foundations/walk/tq_topo.lean:44:9: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.14
theory/phase1_foundations/walk/tq_topo.lean:47:8: warning: declaration uses `sorry`
theory/phase1_foundations/walk/tq_topo.lean:64:29: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.8
theory/phase1_foundations/walk/tq_topo.lean:64:47: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.14
theory/phase1_foundations/walk/tq_topo.lean:65:29: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.25
theory/phase1_foundations/walk/tq_topo.lean:65:47: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.31
theory/phase1_foundations/walk/tq_topo.lean:66:7: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.43
theory/phase1_foundations/walk/tq_topo.lean:77:34: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.24
theory/phase1_foundations/walk/tq_topo.lean:77:54: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.30
theory/phase1_foundations/walk/tq_topo.lean:78:7: error(lean.synthInstanceFailed): failed to synthesize instance of type class
  HSub R R ?m.50
EXIT: 1

$ lean theory/phase2_integration/crawl/attn_iso.lean
theory/phase2_integration/crawl/attn_iso.lean:23:15: error: unexpected token '=>'; expected ')', ',' or ':'
theory/phase2_integration/crawl/attn_iso.lean:32:9: error(lean.unknownIdentifier): Unknown identifier `congr_arg`
theory/phase2_integration/crawl/attn_iso.lean:33:2: error: No goals to be solved
theory/phase2_integration/crawl/attn_iso.lean:41:47: error: unexpected token '=>'; expected ')', ',' or ':'
EXIT: 1

$ lean theory/phase3_optimization/run/zerocopy.lean
theory/phase3_optimization/run/zerocopy.lean:24:14: warning: unused variable `u1`
theory/phase3_optimization/run/zerocopy.lean:47:46: warning: unused variable `h_owner`
EXIT: 0

$ lean theory/phase4_validation/crawl/mask_equiv.lean
EXIT: 0

$ lean theory/phase4_validation/run/subsumption.lean
EXIT: 0
```

### Build summary

| File | Build status | sorry | admit | axiom |
|---|---|---|---|---|
| rope_id.lean | warns, exit 0 | 1 | 0 | 0 |
| tq_topo.lean | **FAILS, exit 1, 8 errors** | 3 | 0 | 0 |
| attn_iso.lean | **FAILS, exit 1, 4 errors** | 0 | 0 | 0 |
| zerocopy.lean | exit 0 | 0 | 0 | 0 |
| mask_equiv.lean | exit 0 | 0 | 0 | 0 |
| subsumption.lean | exit 0 | 0 | 0 | 0 |

Two of the six files **do not compile under Lean 4.29.1** with no
imports/Mathlib. Therefore any theorem inside them — even those whose proof
script does not contain `sorry` — is **not verified**. A `lean` run that
exits non-zero leaves the elaborator in an error state and does not certify
anything in the file.

---

## Per-file findings

### 1. `theory/phase1_foundations/crawl/rope_id.lean`

**Build:** exit 0, but the file contains a `sorry`.

**Theorems present:**

- `rotation_is_orthogonal` (line 43-59) — claim: 2D rotation preserves dot
  product given Pythagorean identity.
  - Proof (lines 46-59):
    ```
    unfold dot rotate
    simp [IsCommRing.sub_eq_add_neg, ...]
    repeat (rw [IsCommRing.add_assoc])
    sorry
    ```
  - **Line 59 contains `sorry`.** Confirmed by grep:
    `59:  sorry`. The `lean` run prints
    `rope_id.lean:43:8: warning: declaration uses 'sorry'`.
  - **Conclusion: NOT PROVEN.** The author's own comments concede the
    failure: "This is getting complex manually. Let's see if we can simplify
    the task." (line 58).

- `rope_rotational_identity` (line 68-73) — top-level claim that p-RoPE
  preserves dot product.
  - Proof body has no `sorry`, but it calls
    `exact rotation_is_orthogonal v w ...` (line 73). Since
    `rotation_is_orthogonal` ends in `sorry`, **this theorem also depends
    transitively on a hole** and is not proven. Lean accepts it because
    `sorry` inhabits any proposition; that does not constitute verification.

**Hidden assumptions / framework concerns:**

- A bespoke `IsCommRing` class is declared (lines 12-24) instead of using
  `Mathlib.Algebra.Ring.Basic`. This is fine for self-contained pedagogy but
  means standard `ring` / `ring_nf` tactics are unavailable, which is *why*
  the proof falls back to `sorry`.
- `h_pythag : cosθ * cosθ + sinθ * sinθ = 1` is taken as an explicit
  hypothesis. Whether the actual `cos_fn` / `sin_fn` of p-RoPE satisfies this
  identity at the floating-point level is **not addressed at all**. The proof
  is over an abstract commutative ring `R`; floats are not a commutative ring
  (no associativity, no exact Pythagorean identity). Even if the `sorry` were
  closed, the result would not transfer to the actual implementation.
- p-RoPE's *defining* property (proportional frequency scaling λ) appears
  only as a parameter name `m_freq_scaled` and a comment on line 8. The
  theorem says *any* Pythagorean (cos, sin) preserves dot products — it is
  the standard 2D rotation lemma, **not** a statement about p-RoPE
  specifically. The "p" in p-RoPE plays no role in the math.

**Severity: BLOCKER.** The named theorem `rotation_is_orthogonal` ends in
`sorry`; the headline theorem `rope_rotational_identity` is therefore
hole-dependent. Additionally, even if closed, the result would be the
classical 2D-rotation identity, not a property specific to p-RoPE, and would
not transfer to floating-point hardware.

**OVERVIEW.md claim being audited:** "p-RoPE Rotational Identity (Lean 4)".
**Status:** UNSUPPORTED.

---

### 2. `theory/phase1_foundations/walk/tq_topo.lean`

**Build: FAILS with 8 errors and 3 `sorry` warnings.** The file does not
typecheck. Every `theorem` in this file is therefore *unchecked* by Lean —
the elaborator gives up before reaching them.

**`sorry` occurrences (grep):**
- Line 27: `def abs {R : Type} [IsOrderedRing R] (a : R) : R := sorry`
- Line 49: `theorem rotation_is_orthogonal ... := sorry`
- Line 71: body of `tq_homomorphism_bound` is just `sorry`.

**Theorems present:**

- `tq_homomorphism_bound` (line 63-71) — the actual TurboQuant claim:
  `abs (dot x y - dot x_q y_q) ≤ error_bound η x y`. Proof body: `sorry`.
- `tq_homomorphism` (line 74-82) — composes the rotation lemma with the
  bound. Calls `rotation_is_orthogonal ... := sorry` (line 49) and
  `tq_homomorphism_bound ... := sorry` (line 71). Both inputs are holes.
- `error_bound` (line 56-59) is `:= η`, a constant function. The comment on
  line 58-59 admits: "Simplified bound for Phase 1.2 Walk". So even if the
  proof closed, the bound proven would be `|⟨x,y⟩ − ⟨T(x),T(y)⟩| ≤ η`
  regardless of `||x||` and `||y||` — physically meaningless when the inputs
  scale.
- `abs` (line 27) is **`def abs ... := sorry`**, a definition that is
  literally undefined. So `abs (...)` in any goal reduces to `sorry`,
  meaning the inequality `abs(...) ≤ η` is `sorry ≤ η` — a goal with no
  computable content.

**Build errors (verbatim, lines from output above):** `HSub R R ?m` cannot
be synthesized at lines 44, 64-66, 77-78. The author tried to use `-` on
elements of the abstract `R` but `IsOrderedRing` (lines 13-25) only declares
`extends Add R, Mul R, Neg R, Zero R, One R, LE R` — **no `Sub`**. The class
hierarchy literally does not let you write `x_q.x - x.x`, which appears in
the hypotheses of every nontrivial theorem.

**Hidden assumptions:**
- The bespoke `IsOrderedRing` class re-implements a fragment of Mathlib
  badly enough to not compile.
- Cauchy-Schwarz is *named* in the comment (line 67-70) but never stated,
  let alone proven.
- TurboQuant's actual algorithm (Hadamard rotation, per-block scale,
  asymptotic `O(d^{-1/2})` distortion of the original paper) appears
  nowhere — there is no Hadamard, no quantizer, no block size.

**Severity: BLOCKER.** File does not compile. The headline theorem
`tq_homomorphism` reduces to `sorry ≤ sorry` if you squint past the eight
type-class errors. Per the evidence rule: build fails → not verified.

**OVERVIEW.md claim:** Not in OVERVIEW.md (this file is the "walk" tier of
Phase 1.2, not surfaced in the public deliverable list). The blog draft
likewise does not name TurboQuant proofs (blog draft is only 17 lines —
see below). However, it is part of the project's claim base via the project
plan. Status: UNSUPPORTED.

---

### 3. `theory/phase2_integration/crawl/attn_iso.lean`

**Build: FAILS with 4 errors.** The file does not parse.

**Errors (verbatim):**
- `attn_iso.lean:23:15: error: unexpected token '=>'`
- `attn_iso.lean:32:9: error: Unknown identifier 'congr_arg'`
- `attn_iso.lean:33:2: error: No goals to be solved`
- `attn_iso.lean:41:47: error: unexpected token '=>'`

The `=>` errors are at the `lambda` syntax on line 22 (`lambda j => ...`)
and line 41 (`lambda k => ...`). In Lean 4 the keyword is `fun`, not
`lambda`; `lambda` is not recognized. So `swa_attention` (line 22) does
not even parse. This in turn leaves the rest of the file unchecked.

`congr_arg` (line 32) is used unqualified; the file has no imports and Lean
4.29.1 with empty environment does not have `congr_arg` in scope. This
suggests the file was once written assuming Mathlib or `Init` imports that
are not in the source.

**Theorems claimed present (but unchecked):**
- `swa_zero_leakage` (line 28-36) — if X and Y agree inside the SWA window,
  outputs match.
- `swa_independent_of_distant_past` (line 39-56) — perturbing a token at
  `j ≤ t - W` does not change output at `t`.

**`sorry` count: 0** (grep confirmed). But this is misleading: the file does
not build, so the *absence of sorry* is irrelevant — Lean never typechecks
the proofs.

**Domain critique (assuming the proofs would close once syntax is fixed):**
- The "attention" model is `sum (mask * X)` (line 22) — i.e. *unweighted
  masked sum of integers*. There is no softmax, no Q/K/V, no exponentiation,
  no normalizer. This is not attention; it is a windowed integer sum. The
  zero-leakage property here is the trivial "if you ignore tokens outside
  the window, then changing them doesn't change the output." That is true
  by definition of `swa_mask`, not a theorem about attention.
- Real SWA in Gemma 4 has interaction between SWA and global layers
  (5-of-6 SWA, 1 global); that interaction is the entire point of the
  "SWA/Global Boundary" claim. The file proves only the SWA half *in
  isolation* — and only for a sum, not attention.

**Severity: BLOCKER.** File does not parse. Even if patched, the model
proven is far weaker than "SWA/Global Boundary" suggests.

**OVERVIEW.md claim:** Phase 2.1 / SWA-Global boundary. Not in the public
artifact list but part of the project plan. Status: UNSUPPORTED.

---

### 4. `theory/phase3_optimization/run/zerocopy.lean`

**Build: exit 0** with two unused-variable warnings.

**Theorems present:**
- `transfer_preserves_address` (line 28-31): given the definition `transfer`
  on line 24 (which by construction sets `region := surface.region` and
  only changes `owner`), the address is the same. Proof: `unfold transfer; simp`.
- `zero_copy_transfer` (line 39-43): `copy_count surface.region (transfer ...).region = 0`.
  Proof: rewrite by the previous theorem then `simp`.
- `architect_goal` (line 47-49): same conclusion, restricted to ANE → AMX.

**`sorry` / `admit` / `axiom`:** zero. File compiles.

**Why this is VACUOUS:**

The model on lines 11-25 is:
```
structure MemoryRegion where address : Nat; size : Nat
structure IOSurface where region : MemoryRegion; owner : HardwareUnit
def transfer (u1 u2) (surface) : IOSurface :=
  { region := surface.region, owner := u2 }
```
`transfer` is *defined* to keep `region` identical and only change `owner`.
The theorem `transfer_preserves_address` then says "after a function that
literally returns `surface.region` unchanged, `surface.region.address` is
unchanged." This is `rfl` modulo a `simp`. It is not a statement about
IOSurfaces, Apple Silicon, ANE, AMX, or kernel-level memory mapping — it is
a record-projection identity over two `Nat` fields.

`copy_count` (line 34-35) is defined as `if r1.address == r2.address then 0
else 1`. Since both regions are literally the same `region` value, the
equality is reflexive and the count is 0 by definition.

**Hidden assumptions:**
- That a real IOSurface handoff between ANE and AMX in Apple Silicon
  corresponds to "the `region` field of a `Mathlib`-free Lean record stays
  the same". This correspondence is asserted in the comment (lines 6-9) and
  has zero formal content. The actual hardware concerns — page table
  attributes, cache coherence between AMX and ANE, IOSurface lock state,
  driver-level reference counts, the firmware DMA path — are not modeled.
- `architect_goal`'s hypothesis `h_owner : surface.owner = HardwareUnit.ANE`
  is **unused** (Lean's own `unused variable 'h_owner'` warning, line 47:46).
  Adding an unused hypothesis is a tell-tale sign of a proof shaped to look
  load-bearing while not being so.

**Severity: BLOCKER (vacuous).** The proof passes typechecking but proves
nothing about zero-copy semantics. It proves: "a function whose definition
returns x.region returns x.region." Per the Evidence Standard's vacuity
clause: a tautology over trivially-equal record fields does not support a
substantive blog claim about Apple Silicon zero-copy IOSurfaces.

**OVERVIEW.md claim:** Not directly listed in OVERVIEW.md's public artifact
list (it's an internal Phase 3.3 deliverable). Status if claimed:
OVERSTATED to the point of vacuity.

---

### 5. `theory/phase4_validation/crawl/mask_equiv.lean`

**Build: exit 0**, no warnings.

**`sorry` / `admit` / `axiom`:** zero.

**Theorems present:**

- `ancestor_le` (line 36-52): if `is_ancestor T j i = true` then `j ≤ i`.
  Real proof, uses `Nat.strongRecOn` and `T.p_lt`. Genuine.
- `list_map_congr` (line 57-64): `(∀ x ∈ l, f x = g x) → l.map f = l.map g`.
  Standard.
- `mask_equivalence` (line 83-91): `sum_tree T f i = sum_path T f i`. Proof
  observes that `sum_path` filter adds `j ≤ i &&` on top of `is_ancestor`,
  and since `j ∈ List.range (i+1)` already implies `j ≤ i`, the extra
  predicate is redundant. Genuine, but trivial.
- `no_sibling_leak` (line 96-99): if `is_ancestor T k i = false` then `k`
  is not in the filtered ancestor list. Closed by `simp [h_not_anc]`.
- `causal_soundness` (line 104-112): if `f` and `g` agree on all ancestors
  of `i`, then `sum_tree T f i = sum_tree T g i`. Genuine.

**What is actually proven:**

The data type is `Nat → Nat`, the "attention" is **`List.foldl (· + ·) 0`
over `f`-values at ancestors**. There is no softmax, no real-valued vector,
no key/query/value projection, no causal mask in the QK^T sense. So:
"Tree-attention equals path-attention" reduces to "filtering a sum over a
range with a predicate `is_ancestor` equals filtering with `j ≤ i ∧
is_ancestor` when the range is `[0, i+1)`." This is true and the proof is
honest, but it is a *combinatorial filter identity*, not an attention
equivalence.

**Hidden assumptions / blog-claim gap:**
- The model is purely set-based (which `j` indices contribute). Real
  attention is normalized by a partition function involving exponentials
  over scores at non-masked positions. The "tree mask" in actual
  speculative-decoding-on-trees changes the *normalizer*, not just the
  support. The proof here proves nothing about the normalizer.
- "Sibling no-leak" is true in this model because siblings of `i` are not
  ancestors of `i`. But in real attention with tree masking, siblings can
  still appear in the *normalizer denominator* unless the mask is set
  correctly there too. Out of scope of the proof.

**Severity: MAJOR.** The proof is real and genuine within its model, but
the model is too weak to back the blog/OVERVIEW claim of "Verifier
Tree-Equivalence" for actual attention. It establishes a set-membership
property, not a numerical attention equality.

**OVERVIEW.md claim:** "Verifier Tree-Equivalence (Lean 4)". Status:
OVERSTATED.

---

### 6. `theory/phase4_validation/run/subsumption.lean`

**Build: exit 0**, no warnings.

**`sorry` / `admit` / `axiom`:** zero.

**Theorem (line 40-49), verbatim:**
```
theorem total_subsumption (GemmaDistribution : Prompt → Distribution)
  (prompt : Prompt) (Drafter : Prompt → Sequence) (s : Sequence) :
  SpeculativeEngine GemmaDistribution prompt Drafter s →
    GemmaDistribution prompt s := by
  intro h
  unfold SpeculativeEngine at h
  cases h with
  | intro _ h_verif =>
    unfold Verified at h_verif
    apply h_verif s
    unfold IsPrefix
    exact ⟨[], List.append_nil s⟩
```

**What is actually proven:**

Look at the definitions (lines 13-33):
```
abbrev Distribution := Sequence → Prop
def Verified (s : Sequence) (D : Distribution) : Prop :=
  ∀ p, IsPrefix p s → D p
def SpeculativeEngine (GemmaDistribution prompt Drafter) : Distribution :=
  fun s => s = Drafter prompt ∧ Verified s (GemmaDistribution prompt)
```

`SpeculativeEngine` outputs `s` only if `Verified s D` holds, i.e. only if
`∀ p, IsPrefix p s → D p`. The theorem instantiates this universal at
`p := s` (since `s` is a prefix of itself, witnessed by appending `[]`) and
gets `D s`. **It is a one-line specialization of a universal quantifier.**

**This proof is a definitional unfolding, not a theorem about LLMs.** The
"Verifier" property `Verified` is *defined* to mean "the distribution holds
on every prefix of the output." The theorem says: "if a property holds on
every prefix including the full sequence, then it holds on the full
sequence." That is `∀ p, P p → P s` applied at `p = s`.

**Hidden assumptions (the load-bearing ones):**
- `GemmaDistribution : Prompt → Distribution` is a free parameter. Nothing
  is said about Gemma 4. In particular, `Distribution := Sequence → Prop`
  is just an arbitrary predicate. There is no probability measure, no
  softmax, no temperature, no token-level distribution, no notion of "the
  drafter samples from a related distribution." This is set theory dressed
  up in LLM vocabulary.
- The `Verified` predicate is a **specification**, not a verifier. It says
  "all prefixes are in the distribution." Whether the actual G4-FlashTree
  speculative-decoding verifier *implements* this predicate is **not
  addressed** — it is taken as a black-box assumption baked into the
  definition of `SpeculativeEngine`.
- "Zero hallucination" in the blog/OVERVIEW means *the generated text is
  consistent with what Gemma 4 would have produced*. The Lean proof says:
  "if a sequence satisfies an arbitrary predicate D on every prefix,
  including itself, then it satisfies D on itself." This is logically true
  but **says nothing about Gemma 4, drafters, or hallucination.** It is
  the trivial fact `(∀p, P p → Q p) ∧ P s → Q s` — modus ponens.

**This is the textbook "vanity proof" pattern from
`prompts/lean4why-why-why.prompt` Layer 7:** the difficulty is encoding,
not insight. Strip the LLM-flavored names and you have:
```
theorem trivial (D : α → Prop) (s : α) :
  (s = s ∧ (∀ p, p = s ∨ ⋯ → D p)) → D s
```
Replace by `Classical.em`-shaped reasoning and it disappears.

**Severity: BLOCKER for the "zero hallucination" claim.** The theorem is
*technically true*, *correctly proven by Lean*, and *epistemically empty
relative to the blog claim*. The blog-claim version would require:
1. A formal model of Gemma 4 (likely a categorical distribution over
   tokens given a prompt).
2. A formal model of the drafter (a different distribution).
3. A formal model of the verifier *algorithm* (not just a predicate),
   showing that the algorithm rejects samples whose conditional probability
   under Gemma is below threshold (or zero, for "zero hallucination").
4. A theorem that conditioned on acceptance, the drafter's *output
   distribution* equals Gemma's.

None of (1)-(4) are present.

**OVERVIEW.md claim:** "The accelerated model's output is guaranteed to be a
strict subset of the original Gemma 4 model's output, eliminating
hallucination risk from the speculation process." Status: UNSUPPORTED. The
Lean proof proves a tautology of the shape "if x ∈ S then x ∈ S".

---

## Cross-file findings

1. **No build system.** No `lakefile.lean`, no `lakefile.toml`, no
   `lean-toolchain`. The proofs were not part of a reproducible Lean
   project. The CLAUDE.md §0 invocation `~/.elan/bin/lake build` does not
   apply (would fail). This means there is no continuous-integration
   guarantee that the proofs ever build together — and in fact two of six
   do not build at all under Lean 4.29.1 (the version elan auto-installs).

2. **Two of six files do not compile.** `tq_topo.lean` and `attn_iso.lean`
   produce hard `error` lines (not warnings) and exit 1. Per the Evidence
   Standard, these contain *no verified theorems*.

3. **Three of the four building files prove tautologies / vacuities.**
   - `zerocopy.lean`: record-projection identity.
   - `subsumption.lean`: `(∀p, P p) → P s`.
   - `mask_equiv.lean`: filter-redundancy on `List.range`.
   Only the algebraic/inductive structure of `mask_equiv.lean`'s
   `ancestor_le` and `causal_soundness` shows any non-trivial content, and
   even there the model is strictly set-theoretic, not numerical.

4. **No Mathlib.** Every file rolls its own algebra (`IsCommRing`,
   `IsOrderedRing`) or avoids algebra entirely. This is the proximate cause
   of the `sorry` in `rope_id.lean` (no `ring` tactic) and the build
   failures in `tq_topo.lean` (incomplete typeclass hierarchy missing
   `Sub`).

5. **No project axiom declarations**, but the framework abuse achieves the
   same effect. `def abs ... := sorry` (tq_topo.lean line 27) is an axiom
   in everything but name: it inhabits the type without proof. Anything
   downstream that calls `abs` is conditional on this hole.

6. **The hypothesis surface, not the conclusion, is where the lying lives.**
   Each "theorem" has plausible LLM-flavored hypothesis names
   (`Drafter`, `Verifier`, `GemmaDistribution`, `IOSurface`, `swa_mask`)
   but the underlying types are `Nat`, `Sequence → Prop`, `Nat`-valued
   record, and `if-then-else`. The theorems prove things about those
   stripped-down types, not about the named domain objects.

7. **Floats vs commutative ring.** Every algebraic theorem (rope_id,
   tq_topo) is stated over an abstract commutative ring `R`. Floating-point
   arithmetic is not a commutative ring (no associativity, denormals,
   etc.). Even if the `sorry`s were closed, the theorems would not transfer
   to the actual GPU/ANE implementation. This is unstated.

---

## Verdict on blog / OVERVIEW claims

OVERVIEW.md headline claims (lines 7-10):

| Claim | Lean artifact | Verdict |
|---|---|---|
| "Correctness: underlying mathematical primitives are sound" | rope_id.lean | UNSUPPORTED. Contains `sorry`; even if closed, proves classical 2D-rotation identity, not a p-RoPE-specific or floating-point fact. |
| "Semantic Integrity: accelerated model's output is a strict subset of Gemma 4's" | subsumption.lean | UNSUPPORTED. The proof is a one-line modus ponens specialization of a universal quantifier; no model of Gemma, drafter, or sampling appears. |
| "Verifier Tree-Equivalence" | mask_equiv.lean | OVERSTATED. Real proof, but in a sum-of-Nat model that is not attention. |
| "p-RoPE Rotational Identity" | rope_id.lean | UNSUPPORTED. `sorry` in the body. |
| "Total Semantic Subsumption" | subsumption.lean | UNSUPPORTED (vacuous). |
| "eliminating hallucination risk" | subsumption.lean | UNSUPPORTED. The Lean proof has no probabilistic content. |

Blog draft (`/Users/amund/amund.blog/drafts/g4-flashtree-formal-verification/index.md`):
The draft is **only 17 lines long** as of audit time — it contains a TL;DR
banner ("this work proves that it is [safe]") and stops. There is therefore
no body text yet to audit for specific overclaims. The TL;DR's "this work
proves that it is" claim is itself OVERSTATED given the audit findings: of
the six Lean files, two do not build, one contains `sorry`, two are
vacuous, and one is honest but proves a model strictly weaker than the
claim language implies.

Phase 3 (zerocopy) and Phase 2 (attn_iso) are not on OVERVIEW.md's public
artifact list, but the project's existence claims them as part of the
proof bundle. Surface them as caveats.

---

## Recommended blog / OVERVIEW disclaimers

Concrete sentences the blog must add to be honest:

1. "Two of the six Lean 4 files in this project (`tq_topo.lean`,
   `attn_iso.lean`) do not currently typecheck under Lean 4.29.1; their
   theorems are unverified."

2. "`rope_id.lean` proves the classical Pythagorean-rotation identity over
   an abstract commutative ring `R`. The proof of `rotation_is_orthogonal`
   ends in `sorry`. The result, even when closed, does not reference
   p-RoPE's frequency-scaling parameter λ and does not transfer to
   IEEE-754 floats; it is the textbook 2D rotation lemma."

3. "`zerocopy.lean` proves that a Lean function defined to return its input
   record's `region` field returns the same `region` field. It does not
   model Apple Silicon IOSurfaces, ANE/AMX driver state, page-table
   sharing, or DMA. The 'zero-copy' claim is not formally supported by
   this artifact."

4. "`subsumption.lean` proves: if a predicate holds on every prefix of a
   sequence (including the sequence itself), then the predicate holds on
   the sequence itself. This is one application of a universal
   quantifier. The proof contains no probabilistic model, no model of
   Gemma 4, no model of speculative decoding, and no model of a verifier
   algorithm. It does not, on its own, support any 'zero hallucination'
   guarantee about the runtime system."

5. "`mask_equiv.lean` proves that filtering a `List.range (i+1)` by
   `is_ancestor` is the same as filtering by `j ≤ i ∧ is_ancestor`. The
   underlying 'attention' is `List.foldl (· + ·) 0` of `Nat → Nat` values
   over ancestors. Real softmax-normalized attention is not modeled."

6. "There is no `lakefile.lean` or `lean-toolchain` pinned in the project.
   Builds are not reproducible; Lean version drift may break or
   accidentally close some of the open `sorry`s in the future."

7. "No proof in the bundle relates a Lean theorem to a measurement on
   actual M3 Ultra hardware. The connection between formal claims and
   runtime behavior is asserted in prose comments only."

---

## One-paragraph summary

Of the six Lean 4 files, only four typecheck under Lean 4.29.1 (no
lakefile, no Mathlib, no toolchain pin); `tq_topo.lean` and `attn_iso.lean`
fail with hard elaboration errors and contain three `sorry`s plus
unparseable `lambda` syntax respectively, so nothing in them is verified.
`rope_id.lean` typechecks but its core lemma `rotation_is_orthogonal` ends
in `sorry`, so the headline `rope_rotational_identity` is hole-dependent.
The three remaining files (`zerocopy.lean`, `mask_equiv.lean`,
`subsumption.lean`) do build cleanly, but `zerocopy.lean` proves a
record-projection tautology, `subsumption.lean` proves a one-line modus
ponens specialization of a universal quantifier dressed in
LLM-vocabulary names (no probability, no Gemma model, no actual
hallucination notion), and `mask_equiv.lean` is the only file with
substantive content but operates over a sum-of-Nats model that is not
softmax attention. The OVERVIEW.md "zero hallucination" claim and the
blog's "this work proves that it is [safe]" TL;DR are therefore
UNSUPPORTED by the Lean artifacts; "p-RoPE Rotational Identity" is
UNSUPPORTED (sorry-bearing); "Verifier Tree-Equivalence" is OVERSTATED
(model too weak). The project needs (a) a `lakefile.lean` + pinned
toolchain so failures are visible in CI, (b) the `sorry`s closed (or
honestly labeled), and (c) blog disclaimers naming the gap between
the abstract types proven about and the runtime objects claimed.
