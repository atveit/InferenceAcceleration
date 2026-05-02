# G4-FlashTree Theory Remediation Plan (2026-05-01)

## Why this exists

Two parallel audits — `audit_lean.md` and `audit_tla_abs.md` — found that the
12 sub-deliveries claimed in `20260501TheoryPlan.md` and surfaced in
`OVERVIEW.md` are largely unverified, vacuous, or directly contradicted by
their own files. Headline issues:

- **Lean:** no `lakefile`, no `lean-toolchain`, no Mathlib; 2 of 6 files do
  not compile; `rope_id.lean` ends in `sorry`; `zerocopy.lean` and
  `subsumption.lean` prove tautologies dressed in LLM vocabulary.
- **TLA+:** `rollback.tla` and `dispatch.tla` use illegal `--` line
  comments and don't parse; `rollback.tla` imports nonexistent `Sets`
  module; `non_interfere.tla` + shipped `.cfg` triggers TLC's
  non-enumerable-quantifier-bound error on `Seq(Tokens)`; `Termination` is
  violated by initial-state stuttering. **No TLC run logs anywhere.**
- **ABS:** `println` demos with no `assert`, hard-coded "cycle counts" and
  analytic curves. `slc_tiling.abs`'s scenario loads 112 MB into a 96 MB
  cache — directly contradicting the "Proven 96 MB residency" claim.

The blog post will not be touched until the underlying artifacts are
honest. This plan defines what that means.

## Strategy: ship a smaller, honest core

We are NOT trying to rescue all 12 sub-deliveries. Better to ship 3-4 real
artifacts than 12 fake ones. The remediation work is split into three
parallel tracks (L, T, A), each with a primary agent. Track R (Reports +
OVERVIEW) waits for L/T/A and reflects whatever evidence actually
materialized.

### Strategic decisions (made in auto mode; revisitable)

1. **Add Mathlib.** Self-contained algebra is the proximate cause of the
   `sorry` in `rope_id.lean` and the `Sub`-missing typeclass failure in
   `tq_topo.lean`. Mathlib is the only path to real algebraic and
   probabilistic proofs.
2. **Delete vacuous artifacts rather than relabel them.** `zerocopy.lean`
   and `subsumption.lean` mislead readers more than they help. If the blog
   needs a "zero copy" or "subsumption" story, the right place is prose +
   the actual implementation, not a Lean tautology.
3. **Demote ABS to behavioral models, not verification.** Rename "Verified"
   to "Illustrates" / "Behavioral model." Add `assert`s where possible.
   Fix `slc_tiling.abs`'s arithmetic.
4. **Capture all model-checker output as committed files** under
   `theory/reports/tlc_runs/`. No log → no claim.
5. **One toolchain per language**, pinned. `lean-toolchain` for Lean;
   `tla2tools.jar` version recorded for TLA+.

### What the new evidence pyramid looks like

```
TIER 1 — PROVEN (Lean, mechanically rechecked via `lake build`)
  Whatever survives Track L, with no sorry/admit/axiom and
  Mathlib-or-stronger backing.

TIER 2 — MODEL-CHECKED UNDER BOUNDS (TLA+ + TLC, with committed logs)
  Whatever survives Track T. Phrase as "no counter-example found at
  bounds N=k", never "proved."

TIER 3 — ILLUSTRATED (ABS / Python / diagrams, with optional assert)
  Whatever survives Track A. Phrase as "behavioral model" / "demo."

TIER 4 — UNVERIFIED PROSE (everything else)
  Where reality lives. Honest about it.
```

The blog must visibly partition claims into these tiers.

---

## Track L (Lean) — owner: agent-L

**Goal:** Ship a `lake build`-green project with at least 2 substantive
theorems, an explicit list of demoted/deleted artifacts, and committed
build output as evidence.

### L0 — Bootstrap (do first)
- Create `lakefile.toml` (or `lakefile.lean`) at repo root.
- Pin `lean-toolchain` to a current stable.
- Add Mathlib dependency.
- Run `lake update && lake build`; capture verbatim output to
  `theory/reports/lake_build.log`.

### L1 — `rope_id.lean` — discharge or honestly bound
- Discharge the `sorry` using Mathlib `ring` / `field_simp`.
- Restate honestly: "rotation by `(cosθ, sinθ)` with `cosθ² + sinθ² = 1`
  preserves dot product on a commutative ring." Drop any "p-RoPE" framing
  that the math doesn't actually carry. Add a note that this does not
  transfer to IEEE-754 floats.

### L2 — `tq_topo.lean` — make it compile or delete
- Drop bespoke `IsOrderedRing`. Use Mathlib's `LinearOrderedField` or
  `NormedAddCommGroup`.
- State a real quantization-error theorem: e.g.
  `|⟨x,y⟩ − ⟨T(x),T(y)⟩| ≤ 2η ‖x‖ ‖y‖ + η² ‖x‖ ‖y‖` given `‖T(z)−z‖ ≤ η‖z‖`.
- If the proof gets too far afield, **delete the file** and note in
  `audit_lean.md` follow-up that the TQ claim is downgraded.

### L3 — `attn_iso.lean` — make it parse or delete
- Replace `lambda` with `fun`. Add proper imports (`Mathlib.Init` etc.).
- Strengthen the model: include a softmax normalizer or scope down
  honestly to "support equality of windowed attention." Don't claim
  "SWA/Global Boundary" if the proof is only one half.

### L4 — `zerocopy.lean` — DELETE
- The current file proves `surface.region = surface.region`. There is no
  honest path to a real Apple Silicon zero-copy theorem in Lean without
  an OS-level model that nobody has time to build. Delete the file and
  document the deletion in `audit_lean.md` follow-up. The blog will
  cover "zero-copy" as engineering prose, not a proof.

### L5 — `mask_equiv.lean` — strengthen
- Keep the `ancestor_le` / `causal_soundness` proofs (genuine).
- Extend to softmax-attention equivalence: prove that if mask zeroes
  non-ancestors and the normalizer is computed only over ancestors, the
  tree-attention output equals the path-attention output for that token.
- This may require Mathlib's `Real` and `Finset.sum`. Acceptable scope.

### L6 — `subsumption.lean` — DELETE or replace
- Current file is modus ponens dressed up. **Default: delete.**
- *Optional* replacement: a real probability-space statement using
  Mathlib's `MeasureTheory`. Only attempt if cheap; otherwise delete and
  document.

### Deliverables
- Working `lake build` with committed log
- Updated/new Lean files for L1, L2, L3, L5 (whatever survives)
- `theory/reports/lean_remediation_notes.md` — per-file decisions, with
  rationale for any deletion
- All `sorry`/`admit` count = 0 in surviving files (or explicitly listed
  with rationale)

---

## Track T (TLA+) — owner: agent-T

**Goal:** All shipped `.tla` files parse under standard TLC. Each has a
working `MC.tla` + `MC.cfg`. Each has a committed run log under
`theory/reports/tlc_runs/`.

### T0 — Toolchain pin
- Document the TLC version used (`/Users/amund/.tla/tla2tools.jar` v2.19,
  OpenJDK 21) in a `theory/reports/tla_toolchain.md`.

### T1 — `rollback.tla`
- Replace `--` line comments with `\*`.
- Replace `EXTENDS Integers, Sets` with `EXTENDS Integers, FiniteSets`.
- Add `theory/phase2_integration/walk/rollback.cfg`.
- Optional but valuable: keep `UnsafeRollback` in a separate
  `UnsafeNext`, run TLC twice — once with `Next`, once with `UnsafeNext`
  — and commit both logs. The unsafe variant should produce a
  counter-example. That comparison is the actual evidence.

### T2 — `dispatch.tla`
- Replace `--` line comments with `\*`.
- Fix `DeadlockFree` so it's not trivially false in `Init`. Likely
  `DeadlockFree == [](amx_status = "Idle" /\ ane_status = "Idle"
                     /\ buffer_state = "Empty" => <>(...))` or similar.
  If it's not salvageable as stated, drop it and only ship safety
  invariants `DataIntegrity` and `NoCollision`.
- Add fairness if liveness is desired.
- Commit `dispatch.cfg` and run log.

### T3 — `non_interfere.tla`
- Replace `Seq(Tokens)` with a bounded helper, e.g.
  `BoundedSeq(S, N) == UNION { [1..n -> S] : n \in 0..N }`. Adjust the
  `Init` and `DrafterPropose` predicates accordingly.
- Either:
  - (a) Add fairness to make `Termination` actually hold, OR
  - (b) Remove `Termination` from the spec and document that the proof
    is safety-only.
- Commit working `.cfg` (replace the existing one if needed) and run log.

### Deliverables
- All 3 `.tla` files parse under TLC2 v2.19 with no manual edits to a
  working copy.
- `theory/phase*/walk/<name>.cfg` exist and are usable.
- `theory/reports/tlc_runs/<name>.log` exists per spec.
- `theory/reports/tla_remediation_notes.md` summarizing what was changed
  and what bounds the runs cover. Be explicit that bounded model checking
  is not a proof for unbounded N.

---

## Track A (ABS) — owner: agent-A

**Goal:** Honest framing. Files demoted from "verification" to
"behavioral model" or "demo." Arithmetic that contradicts claims is
fixed. `assert`s added where possible.

### A0 — Try to install ABS toolchain
- Attempt `brew install abs-models/abs/absc` or similar. If not feasible,
  document the failure in `theory/reports/abs_toolchain.md`. Do not
  fabricate runs.

### A1 — `slc_tiling.abs`
- The current scenario loads 16 MB LUT + 12 × 8 MB tiles = 112 MB into a
  96 MB cache. Either:
  - reduce the working set to fit (e.g. 8 tiles × 8 MB + 16 MB LUT = 80 MB), OR
  - add an LRU eviction policy and demonstrate steady-state residency.
- Add `assert occupancy <= maxCapacity` (or whatever ABS supports).
- Document in source comments what this *demonstrates* vs *proves*.

### A2 — `eml_ops.abs`
- Add `assert` connecting `Softmax(p,q)` and `EML(log p, log q)` numerically.
- Acknowledge in comments that the `latency = 24` and `latency = 1`
  numbers are placeholder constants, not measured.

### A3 — `tree_perf.abs`
- Add `assert` that the analytic curve has its maximum at the predicted B
  (or commit to a measured value).
- Acknowledge that this is a closed-form evaluation, not a verification.

### A4 — Relabel everywhere
- In each `.abs` file's header comment, change "Verified ..." to
  "Behavioral model: ..." or "Illustrates ...".
- Update `20260501TheoryPlan.md`'s "Improved Result" cells for ABS rows
  accordingly (this is a Track R job, but flag it here).

### Deliverables
- Three updated `.abs` files with honest headers, `assert`s, and (for
  slc_tiling) corrected arithmetic.
- `theory/reports/abs_remediation_notes.md` documenting what was changed.
- If `absc` is installable: a captured run log per file. If not: explicit
  "toolchain not available; files reviewed by inspection only."

---

## Track R (Reports + OVERVIEW) — owner: agent-R, blocked by L/T/A

After L, T, A complete:

- Update `OVERVIEW.md` to reflect tier-classified evidence (Tier 1/2/3/4).
- Update `20260501TheoryPlan.md`'s status column to match reality.
- Rewrite or delete `theory/reports/phase4_2_validation_critique.md` —
  it currently makes a demonstrably false claim ("model checker
  successfully explores the state space" on a spec where TLC errors
  immediately on `Seq(Tokens)`).
- Update `theory/reports/final_synthesis.md` to honest evidence levels.

## Iterate

Each agent is expected to *iterate*: run → fail → fix → run → … until the
deliverable's evidence is reproducible. If an artifact resists
remediation, the right move is to delete it and document the deletion.
"Honestly demoted" beats "still broken."

When in doubt, the blog will be retitled by the user later — do not
optimize for the current title.

---

## Standing rules (apply throughout)

### Rule 1 — Log everything

Every toolchain invocation, every fix attempt, every decision must land
in a committed log file. The audits succeeded because verbatim `lean`
and `tlc` outputs were pasted into the report. Continue that discipline.
At minimum:

- `theory/reports/lake_build.log` — full Lean build output, append after
  each iteration with a date header.
- `theory/reports/tlc_runs/<spec>.log` — full TLC stdout/stderr per run,
  per spec, including parse-failure runs (they're evidence too).
- `theory/reports/abs_runs/<file>.log` — same, if `absc` is installed.
- Each agent maintains a running notes `.md` (`*_remediation_notes.md`)
  with timestamped entries: what was attempted, what failed, what was
  fixed. Update incrementally — don't batch.

The audits' "no output, no evidence" rule applies in reverse here: every
claim of "fixed" or "verified" must point to a line in a committed log
file.

### Rule 2 — Apply `prompts/` to the new artifacts

The `prompts/` directory has 7 scrutiny prompts:

- `lean4critique.prompt`, `lean4why-why-why.prompt`
- `tlaplusCritique.prompt`, `tlaplusWhy-why-why.prompt`
- `absCritique.prompt`, `absWhy-why-why.prompt`
- `WhyWhyWhyForFormalLanguage.prompt` (general)

These are not just for the initial audit. After each remediation pass,
**apply the relevant prompt to the new artifact** and write findings
into the remediation notes. The prompts ask: hidden assumptions, vacuity
risk, what could be stronger, what is the *why* behind each step. A
freshly-fixed file should pass this lens before being marked done. If
the prompt surfaces a new gap, iterate again.

Schedule:
- Every Lean file edit → re-read `lean4critique.prompt`'s checklist for
  that file, write a one-paragraph self-critique into
  `lean_remediation_notes.md`.
- Every TLC run → answer `tlaplusCritique.prompt`'s questions about
  the spec being run.
- Every ABS edit → answer `absCritique.prompt`'s questions.

If the self-critique surfaces a finding the agent can't fix in scope,
record it as a "deferred finding" and move on — do not delete or hide it.
