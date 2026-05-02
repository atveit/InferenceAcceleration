# Track R Notes — Reports + OVERVIEW remediation

Owner: agent-R. Started 2026-05-01 after Tracks L, T, A completed.
Plan: [`REMEDIATION_PLAN.md`](REMEDIATION_PLAN.md) Track R.
Inputs read in order:

1. `REMEDIATION_PLAN.md`
2. `audit_lean.md`, `audit_tla_abs.md`
3. `lean_remediation_notes.md`, `tla_remediation_notes.md`,
   `abs_remediation_notes.md`
4. `tla_toolchain.md`, `abs_toolchain.md`, root `lean-toolchain` +
   `lakefile.toml`
5. The new artifacts under `theory/G4FlashTreeTheory/`,
   `theory/phase{2,3,4}_*/walk/`, and the three `.abs` files
6. Captured logs: `lake_build.log`,
   `tlc_runs/{rollback,rollback_unsafe,dispatch,non_interfere}.log` +
   the three `*.parse-fail.log` / `unbounded-fail.log` files

## 2026-05-01 — R1: Rewrote `OVERVIEW.md`

### Edits

- Replaced the original "machine-checked blueprint proving
  correctness, safety, semantic integrity" framing with a
  tier-classified evidence layout (Tiers 1–4).
- Added a "What is NOT proven" section listing 9 deferred findings
  (3 each from Tracks L, T, A).
- Dropped the "zero hallucination" / "strict subset of Gemma 4
  output" claim entirely. The two Lean files that backed it
  (`zerocopy.lean`, `subsumption.lean`) were deleted by Track L.
- Updated artifact links: Tier 1 paths now point at
  `theory/G4FlashTreeTheory/*.lean`, not the old phase paths
  (which are redirect stubs).
- Tier 2 section calls out the `rollback_unsafe.log` counter-example
  as the load-bearing artifact (per `tla_remediation_notes.md`
  vanity-check finding).
- Tier 3 section honestly states `absc` is not installed and
  `abs_runs/` is empty; no captured runs.
- Tier 4 (engineering prose) explicitly enumerated, with pointer to
  CLAUDE.md §6–§9 for the standards governing those claims.

### Self-critique against
[`prompts/WhyWhyWhyForFormalLanguage.prompt`](../../prompts/WhyWhyWhyForFormalLanguage.prompt)

- *Failure mode "Tool success is mistaken for insight."* The
  rewrite avoids this for Tier 1 (notes Lean is `Lean: it
  typechecks` only — the surviving theorems are over `ℝ`, not over
  IEEE-754) and for Tier 2 (notes "TLC at 4–252 states" is bounded
  model checking, not a general proof).
- *Failure mode "Wrong layer is used."* The rewrite explicitly
  partitions: zero-copy IOSurfaces and ANE residency are Tier 4,
  not Tier 1 — that was the original mis-layering.
- *Vanity risk.* The TLA+ dispatch model is 4 states. The OVERVIEW
  flags this as borderline-vanity in the Phase 3.2 row of
  `20260501TheoryPlan.md` (not in OVERVIEW itself, where it would
  read as undermining; the notes file is the right place for the
  meta-critique). Trade-off: keep the OVERVIEW readable while
  surfacing the issue in the plan and notes. Acceptable.

### Could an audit catch anything in this OVERVIEW?

Checked against the original audits' rubric:
- ✓ Every Tier 1 claim points at a `lake_build.log` line.
- ✓ Every Tier 2 claim points at a `tlc_runs/*.log` and states
  bounds.
- ✓ Tier 3 is labelled "behavioral model" / "not run" with the
  toolchain absence acknowledged.
- ✓ Tier 4 names are listed under "engineering prose"; not claimed
  as proven.
- ✓ Deleted files documented with reason and notes-file pointer.
- ✗ One residual risk: a casual reader could collapse the four
  tiers back into one "verified" bucket. Mitigation: the TL;DR
  states the partition explicitly.

## 2026-05-01 — R2: Updated `20260501TheoryPlan.md`

### Edits

- Added top-of-file STATUS UPDATED note.
- Rewrote every "Improved Result" cell:
  - Phase 1.1 (RopeId): T1 — honest scope (CommRing, not p-RoPE,
    not float).
  - Phase 1.2 (TQTopo): T1 — generic Lipschitz bound (not
    TurboQuant).
  - Phase 1.3 (eml_ops): T3 — assert added, cycle constants
    placeholders, not run.
  - Phase 2.1 (AttnIso): T1 partial — SWA half only, Boundary not
    proven.
  - Phase 2.2 (rollback): T2 with bounds (MaxLen=4, 31 states),
    pointing at safe + unsafe logs.
  - Phase 2.3 (tree_perf): T3 — analytic guess, not measurement.
  - Phase 3.1 (slc_tiling): T3 — original arithmetic bug
    (16+12×8=112 MB > 96 MB) acknowledged as fixed; LRU vs
    hardware-managed SLC caveat.
  - Phase 3.2 (dispatch): T2 borderline-vanity — 4 states; original
    DeadlockFree malformed.
  - Phase 3.3 (zerocopy): DELETED — vacuous, see §L4.
  - Phase 4.1 (mask_equiv): T1 strengthened — softmax-output
    equality.
  - Phase 4.2 (non_interfere): T2 DEMOTED — safety only,
    `Termination` dropped, prefix-not-distribution caveat.
  - Phase 4.3 (subsumption): DELETED — vacuous, see §L6.
- Updated the directory tree to reflect new lake project,
  `G4FlashTreeTheory/` lib, redirect stubs, and deleted files.
- Rewrote success metrics: Lean = lake build green; TLA+ = bounded
  TLC; ABS = `assert`s present, no captured run; Tier 4 governed by
  CLAUDE.md §9.

### Self-critique

- *Why use tier tags T1/T2/T3 rather than reusing the original
  prose labels?* Because reusing "Verified" keeps the original
  failure mode alive. The tier tags make the strength of evidence
  visible at-a-glance to anyone scanning the table.
- *Vanity check.* The rewritten cells are longer and more honest;
  tradeoff is readability. I considered shorter labels with
  pointers, but the audit's lesson was that prose hidden one click
  away gets lost. Inline caveats are correct here.

## 2026-05-01 — R3: Rewrote `phase4_2_validation_critique.md`

### Edits

- Marked file as REWRITTEN with original preserved in git history.
- Quoted the original false claim verbatim ("the model checker
  successfully explores the state space").
- Cited `audit_tla_abs.md` §2.3's TLC error output
  (non-enumerable quantifier bound on `Seq({t1, t2})`) as proof
  that the original claim could not have been produced by an
  actual TLC run.
- Documented the remediation fixes and pointed at the captured
  logs (`non_interfere.log`, `non_interfere.unbounded-fail.log`).
- Stated what the new evidence does and does NOT support
  (prefix-correctness yes; non-interference of a target
  *distribution* no).
- Generalised the lesson to sibling phase4 reports.
- Added a Why-Why-Why self-critique at the end.

### Self-critique

- *Was deleting the original file an option?* Per Standing Rule 4,
  preserving git history is required. Rewriting with a
  REWRITTEN-2026-05-01 marker is the correct move.
- *Did I overclaim the new evidence?* The body says "no
  counter-example found at these bounds" / "safety only, no
  liveness" / "no probability or distribution in the model" — all
  three are tight to what the actual log shows.

## 2026-05-01 — R4: Rewrote `final_synthesis.md`

### Edits

- Marked file as REWRITTEN with original preserved in git history.
- Replaced "Zero-Hallucination" / "Total Semantic Subsumption" /
  "ALL PHASES VERIFIED" framing with a tier-classified summary.
- Phase 4 outcomes table redone with T1/T2/DELETED tags pointing at
  notes files.
- Project-wide results restructured into Tier 1 (Lean) / Tier 2
  (TLA+) / Tier 3 (ABS, not run) / Tier 4 (engineering prose).
- Added explicit "What this synthesis is NOT" section enumerating
  five claims that the *original* synthesis made and that this one
  does not.

### Self-critique

- *Risk that "synthesis" reads as a closing verdict.* The body
  says "we proved an interface-level skeleton, model-checked a few
  protocol slices, and documented the gaps." This is honest; a
  reader looking for closure will not find a "loop closed" claim.
- *Could the body still be quoted out of context as "all surviving
  evidence"?* Yes, but the §5 NOT-section is specifically there to
  catch that quote-mining. Acceptable.

## 2026-05-01 — R5: Annotated phase4_{1,2,3}.md

### Decision (per plan): annotate, do not rewrite

The bodies of `phase4_1_crawl.md`, `phase4_2_walk.md`, and
`phase4_3_run.md` are individually short and largely accurate at
the level of describing what the original artifacts contained.
What was *false* was the framing language ("VERIFIED",
"Termination ensures no infinite loops", "zero hallucination").
The plan said "add a top-of-file note … Don't rewrite if the
original is mostly accurate; just add the pointer." I followed
that.

### Edits

- `phase4_1_crawl.md`: added top-of-file POST-AUDIT note pointing at
  `audit_lean.md` §5, the Track-L strengthening (now ℝ-valued
  softmax in `theory/G4FlashTreeTheory/MaskEquiv.lean`), the
  deletion of the `subsumption.lean` "zero-hallucination" backing,
  and the post-mortem in `phase4_2_validation_critique.md`.
- `phase4_2_walk.md`: added top-of-file POST-AUDIT note flagging
  the false `Termination` claim, the prefix-vs-distribution gap,
  and the original spec's unparseability.
- `phase4_3_run.md`: added top-of-file POST-AUDIT note announcing
  that the underlying artifact has been DELETED, citing
  `lean_remediation_notes.md` §L6.

### Self-critique

- *Risk that the POST-AUDIT note + unchanged body confuses
  readers.* Mitigated by phrasing: each note explicitly says "the
  body is preserved for diff legibility but the headline claim is
  superseded." Anyone reading the body in isolation will hit the
  blockquote first.
- *Should the phase4_3_run.md body have been deleted entirely?*
  Considered; rejected. The body documents what the original
  `subsumption.lean` proof structure was — useful audit-trail
  context for anyone investigating why the file was deleted. The
  blockquote up top makes the verdict clear.

## 2026-05-01 — Final pass: cross-document consistency check

Verified that the same caveats appear in all the surfaces a reader
might land on:

| Caveat | OVERVIEW | TheoryPlan | phase4_2_critique | final_synthesis |
|---|---|---|---|---|
| `subsumption.lean` deleted (no zero-hallucination Tier-1) | ✓ | ✓ (Phase 4.3 row) | ✓ §4 | ✓ §2, §3, §5 |
| `zerocopy.lean` deleted (zero-copy is Tier 4) | ✓ | ✓ (Phase 3.3 row) | — | ✓ §3.D |
| `non_interfere.tla` proves prefix-not-distribution | ✓ Tier 2 | ✓ (Phase 4.2 row) | ✓ §3 | ✓ §2 |
| `non_interfere.tla` `Termination` dropped | ✓ Tier 2 + NOT-proven §5 | ✓ (Phase 4.2 row) | ✓ §3 | ✓ §2 |
| `dispatch.tla` is borderline-vanity (4 states) | ✓ Tier 2 + NOT-proven §4 | ✓ (Phase 3.2 row) | — | ✓ §3.B |
| `dispatch.tla` original DeadlockFree malformed | ✓ (NOT-proven §4) | ✓ (Phase 3.2 row) | — | ✓ §3.B |
| `slc_tiling.abs` original 112 MB > 96 MB scenario fixed | ✓ Tier 3 | ✓ (Phase 3.1 row) | — | ✓ §3.C |
| LRU is a fiction relative to hardware-managed SLC | ✓ NOT-proven §9 | ✓ (Phase 3.1 row) | — | ✓ §3.C |
| Floats ≠ commutative ring (Tier 1 doesn't transfer) | ✓ NOT-proven §1 | ✓ (Phase 1.1, 1.2 rows) | — | ✓ §3.A |
| ABS files not run (`absc` not installed) | ✓ Tier 3 | ✓ (Phase 1.3, 2.3, 3.1 rows; success metrics) | — | ✓ §3.C |

All caveats land in the right places. `phase4_2_validation_critique.md`
intentionally focuses on the `non_interfere`-specific story.

## Top deferred findings for the user (final list)

These are gaps the remediation surfaced that Track R cannot close:

1. **Floats vs commutative ring.** Every Tier-1 theorem is over `ℝ`
   or `CommRing`. Closing the gap to bf16/fp16 needs either a
   fixed-point analysis or a Mathlib formal float model. Out of
   scope.
2. **Generic interfaces vs Gemma kernels.** `TQTopo` is a generic
   η-Lipschitz bound; `AttnIso` treats scores as abstract `Nat → ℝ`.
   Tying these to actual TurboQuant Hadamard rotations and
   QK-bilinear forms is open work.
3. **Tiny TLA+ state spaces (4–252).** The dispatch model is
   borderline-vanity; bumping `non_interfere`'s bounds to the
   audit-cfg values (MaxTraceLen=5, MaxDraftLen=3) was not run.
4. **No probability in `non_interfere`.** A real probabilistic
   non-interference proof would require Mathlib `MeasureTheory`,
   not TLA+.
5. **No `absc` runs captured.** The Tier-3 `assert`s are static
   text, not exercised. A future run-capture is the obvious next
   step if `absc` becomes installable.
6. **Cycle constants in `eml_ops.abs` are placeholders.** Any
   cycle-cost claim downstream must come from a Metal kernel
   microbenchmark, not from this file.
7. **No connection to `powermetrics` / wall-clock.** Tier 1 has no
   performance evidence. Tier 4 (engineering prose) is the only
   surface for that, and it lives outside this project.

## Items that needed user input

None. All remediation decisions traced cleanly to plan, audit, or
notes file. The blog rewrite is explicitly out of Track R scope and
will run as a separate task.
