# TLA+ Remediation Notes (Track T)

Owner: agent-T. Started 2026-05-01.

Toolchain pinned in `tla_toolchain.md`. Every claim of "checked" /
"green" below points to a log file under `theory/reports/tlc_runs/`.
Bounded model checking is **not** a proof for unbounded N — explicit
bounds are stated for each run.

---

## 2026-05-01 19:11 — Audit baseline confirmed (parse-fail evidence)

Ran TLC against the as-shipped files (no edits) to capture the parse
failures the audit reported, before patching. To force the parser to
actually run (rather than die on missing config), I passed a
`/tmp/<spec>_stub.cfg` containing only `SPECIFICATION Spec`.

| spec | log | result |
|---|---|---|
| `rollback.tla` (as-shipped) | `tlc_runs/rollback.parse-fail.log` | **Parse Error** — line 29, col 11, token "Unsafe". Cause: `--` line comments + missing `Sets` module. |
| `dispatch.tla` (as-shipped) | `tlc_runs/dispatch.parse-fail.log` | **Parse Error** — line 13, col 8, token "ANE". Cause: `--` line comments. |
| `non_interfere.tla` (as-shipped + shipped `.cfg`) | `tlc_runs/non_interfere.unbounded-fail.log` | **TLC error** — `non-enumerable quantifier bound Seq({t1, t2})` at line 22, col 17. Zero states generated. |

This directly contradicts `theory/reports/phase4_2_validation_critique.md:35`
which claims "the model checker successfully explores the state space".
That sentence cannot be true against the shipped artefact — TLC errors
out on `Seq(Tokens)` before generating any state. **Track R must rewrite
that report.**

---

## 2026-05-01 19:11 — T1: rollback.tla fixed and model-checked

Fixes to `theory/phase2_integration/walk/rollback.tla`:

- `EXTENDS Integers, Sets` → `EXTENDS Integers, FiniteSets`.
- All seven `--` line comments rewritten as `\*`.
- `\forall` and `\exists` already use the unicode-equivalents TLA+
  accepts; left untouched.
- Added a separate `UnsafeNext` next-state relation (still using
  `UnsafeRollback`) and a separate `UnsafeSpec`. The shipped Safe `Spec`
  uses `Next` (no UnsafeRollback). This lets us model-check the safe
  spec for `NoGhostReads` *and* model-check the unsafe spec to produce
  a real counter-example trace.

Shipped `rollback.cfg`:
- `SPECIFICATION Spec`
- `INVARIANT NoGhostReads`
- `CONSTANT MaxLen = 4`

Shipped `rollback_unsafe.cfg`:
- `SPECIFICATION UnsafeSpec`
- `INVARIANT NoGhostReads`
- `CONSTANT MaxLen = 4`

### Run 1 (safe) — `tlc_runs/rollback.log`

```
189 states generated, 31 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 9.
Model checking completed. No error has been found.
```

→ At `MaxLen = 4`, `NoGhostReads` is not violated across all 31
reachable states.

### Run 2 (unsafe) — `tlc_runs/rollback_unsafe.log`

TLC produces a **4-state counter-example**:

```
State 1: len = 0, pending_reads = {}                  (Init)
State 2: len = 1, pending_reads = {}                  (Extend)
State 3: len = 1, pending_reads = {1}                 (StartRead)
State 4: len = 0, pending_reads = {1}                 (UnsafeRollback) -- VIOLATION
```

i.e. `pending_reads = {1}` while `len = 0`, so `i = 1 > len = 0` —
ghost read. This is the actual evidence that the `SafeRollback` guard
`\A i \in pending_reads : i <= k` is load-bearing.

### Self-critique (tlaplusCritique.prompt + Why-why-why)

- **State-space scaling**: 31 states at MaxLen=4. The state space
  scales roughly as `MaxLen × 2^MaxLen` (pending_reads is a subset of
  `1..len`), so MaxLen=8 would already be ~2000 states. We're not
  pushing the boundary; the proof is for the structure of the
  protocol, not for any particular bound.
- **Why this invariant?** `NoGhostReads` is the natural truth of the
  data structure: a pending read on index `i` is meaningful only while
  `i ≤ len`. It's not auxiliary scaffolding.
- **Why does this matter for the real system?** The real-world
  property is "after a rollback truncates the KV cache, no in-flight
  attention read can read past the new tail." The spec abstracts the
  cache contents to just `len` and the readers to integer indices,
  losing the actual data. So this is a *protocol* proof, not a memory
  safety proof. Real-world hazards (cache-line residency, GPU/ANE
  memory ordering, concurrent extends) are not modelled.
- **Vanity check**: would the proof exist without TLC? Without TLC
  this is a hand proof: SafeRollback's guard plus the monotone
  growth of pending_reads via FinishRead implies the invariant. TLC
  *adds* the 4-state unsafe counter-example, which is the most useful
  artefact in the file. Without the unsafe variant, this would be
  borderline vanity.
- **Deferred finding**: the spec excludes the case of overlapping
  Extend + StartRead (atomic-ish in the model). In real hardware
  these can race; the spec doesn't speak to that.

---

## 2026-05-01 19:12 — T2: dispatch.tla fixed and model-checked

Fixes to `theory/phase3_optimization/walk/dispatch.tla`:

- All seven `--` line comments rewritten as `\*`.
- Added `WF_vars(Next)` to `Spec` (was safety-only; needed for the
  salvaged liveness property).
- **Removed the broken `DeadlockFree` predicate** (`~(amx_status =
  "Idle" /\ ane_status = "Idle" /\ buffer_state = "Empty")`) — it is
  trivially false in `Init` since `Init` puts everything in
  Idle/Idle/Empty. Replaced with a salvaged `Liveness == <>(buffer_state
  /= "Empty")`, which actually captures "from the all-Idle initial
  state, the system makes progress" under weak fairness.

Shipped `dispatch.cfg`:
- `SPECIFICATION Spec`
- `INVARIANTS DataIntegrity, NoCollision`
- `PROPERTIES Liveness`

### Run — `tlc_runs/dispatch.log`

```
5 states generated, 4 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 4.
Model checking completed. No error has been found.
```

→ All 4 reachable states satisfy `DataIntegrity` and `NoCollision`,
and `Liveness` holds (under `WF_vars(Next)`).

### Self-critique (Critique + Why-why-why)

- **State-space size**: 4 distinct states. This is so small that TLC
  is over-credit — a hand-drawn state diagram would carry the same
  evidence (Idle/Idle/Empty → Idle/Writing/Writing → Idle/Idle/Ready
  → Reading/Idle/Reading → Idle/Idle/Empty). The TLC run mostly
  serves as a parser/well-formedness check.
- **Why this abstraction?** Three string-typed status variables. This
  hides every hardware-level concern: cache coherence, IOSurface
  lifetimes, partial writes, error paths, concurrent multi-tile
  pipelines, AMX-vs-ANE ordering at the memory-controller level. The
  audit's verdict ("protocol skeleton, not 'AMX/ANE Dispatch Safety'
  as a system property") stands.
- **Why does liveness matter at this bound?** With only 4 states, the
  `Liveness` property is really just "from Init, fire once". Under
  `WF_vars(Next)` this is automatic — once `StartANE` is enabled
  forever, it must eventually fire. The liveness check is more a
  smoke-test of fairness syntax than a deep claim.
- **Vanity check**: this is borderline vanity. The right artefact for
  this layer of the system is a Metal kernel queue diagram + a unit
  test that asserts no `amx_status = "Reading" /\ ane_status =
  "Writing"` ever happens at runtime via `os_signpost`. The TLA+
  spec is a teaching diagram in TLA+ form, not a verification
  artefact.
- **Deferred finding**: the original `DeadlockFree` was a real bug
  (false in Init). Anyone who claimed they'd model-checked this spec
  was either not running it, or running a different spec. Worth
  flagging in `phase4_2_validation_critique.md` rewrite.

---

## 2026-05-01 19:13 — T3: non_interfere.tla fixed and model-checked

Fixes to `theory/phase4_validation/walk/non_interfere.tla`:

- Defined `BoundedSeq(S, N) == UNION { [1..n -> S] : n \in 0..N }`.
- Replaced `Seq(Tokens)` with `BoundedSeq(Tokens, MaxTraceLen)` /
  `BoundedSeq(Tokens, MaxDraftLen)` in `Init`, `DrafterPropose`, and
  `TypeOK`.
- Added `WF_Vars(DrafterPropose)` to `Spec` (not strictly needed for
  the safety-only result we're shipping, but makes Spec self-consistent
  and avoids initial-state stutter from being legal).
- **Dropped `Termination`.** Per the audit, even with bounded
  variants, `Termination` is violated by initial-state stuttering;
  WF_Vars(Verify) alone doesn't help (Verify is disabled in Init);
  WF_Vars(DrafterPropose) helps but TLC's WF on an action with a
  `\E s \in BoundedSeq(...)` body doesn't generally guarantee any
  particular drafter behaviour. Rather than encode a heavier
  scheduler, we ship safety-only as the audit (T3 option (b))
  recommended. Note appended at the bottom of the spec explaining
  the choice.

Shipped `non_interfere.cfg`:
- `SPECIFICATION Spec`
- `INVARIANT NonInterference`
- `CONSTANTS Tokens = {t1, t2}, MaxTraceLen = 3, MaxDraftLen = 2`
- `CHECK_DEADLOCK FALSE` — when `accepted_output = target_model_trace`,
  both actions become disabled, but that's the *intended* terminal
  state, not a stuck system.

### Run — `tlc_runs/non_interfere.log`

```
Finished computing initial states: 14 distinct states generated.
422 states generated, 252 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 4.
Model checking completed. No error has been found.
```

→ At `|Tokens|=2, MaxTraceLen=3, MaxDraftLen=2`, the `NonInterference`
invariant holds across all 252 reachable states.

### Self-critique (Critique + Why-why-why)

- **State-space scaling**: 252 distinct states; reachable graph depth 4.
  Bumping bounds to MaxTraceLen=5, MaxDraftLen=3 (the audit-cfg
  values) would push state count well beyond `|Tokens|^MaxTraceLen +
  |Tokens|^MaxDraftLen` cross-products. We did not run that, and the
  paper's claim does not generalize to arbitrary bounds in any case.
- **Why these bounds?** MaxTraceLen=3 / MaxDraftLen=2 covers the
  three semantically distinct cases (full match, partial match, full
  mismatch) at a state space TLC explores in <1 s. Bigger bounds add
  combinatorial duplicates of the same patterns; they don't add new
  semantic territory.
- **Why this invariant?** `accepted_output` is a prefix of
  `target_model_trace`. This is the *prefix* form of speculative
  decoding correctness. It is **structurally weaker** than the
  OVERVIEW claim "drafter cannot bias the target distribution":
  - There is no probability, sampling, or temperature in the model.
  - `target_model_trace` is a single fixed sequence chosen
    non-deterministically in `Init`.
  - The verifier is deterministic LCP-then-correction-token.
  So this proves: "given a fixed reference trace and an LCP-
  then-correction verifier, an arbitrary drafter cannot produce an
  output that disagrees with that reference trace as a prefix." That
  is a near-tautology of the LCP rule, not a probabilistic
  non-interference theorem. `lean_remediation_notes.md` and the
  blog must be honest about this gap.
- **Why drop Termination?** Two reasons:
  1. With WF on Verify only (the original spec), Verify is disabled
     in Init (no proposal yet) so the system can stutter at Init
     forever. Termination violated.
  2. With WF on both DrafterPropose and Verify, the system makes
     progress, but TLC's WF semantics on an action with an
     existential body (`\E s \in BoundedSeq...`) does not force the
     existential to pick any particular witness; in particular, it
     does not force progress toward `accepted_output =
     target_model_trace`. The right encoding requires a deterministic
     scheduler over draft choices, which is more spec than this
     paper claim warrants. Safety-only is honest.
- **Vanity check**: the safety property is real and it would not be
  obvious from a hand proof to a non-spec-language reader, but it is
  also far weaker than the prose claim. The risk is that "TLC says
  NonInterference holds" gets quoted in the blog as "we proved
  speculative decoding is non-interfering" without the prefix-of-fixed-
  trace caveat. **Track R must enforce the caveat in OVERVIEW and the
  validation critique.**
- **Deferred finding**: a real probabilistic non-interference proof
  would live in Lean (with `MeasureTheory`), not TLA+. The TLA+
  artefact should be re-titled in OVERVIEW as
  "Speculative-decoding prefix correctness (TLA+, bounded)", not
  "Non-interference of drafter".

---

## Final summary table

| Spec | Bounds | Distinct states | Property | Result | Log |
|---|---|---|---|---|---|
| `rollback.tla` (Safe `Spec`) | MaxLen=4 | 31 | `NoGhostReads` (safety) | no counter-example found | `tlc_runs/rollback.log` |
| `rollback.tla` (`UnsafeSpec`, bonus) | MaxLen=4 | 8 (search aborts at depth 4) | `NoGhostReads` (safety) | **violated**, 4-state counter-example | `tlc_runs/rollback_unsafe.log` |
| `dispatch.tla` | (none) | 4 | `DataIntegrity`, `NoCollision` (safety); `Liveness == <>(buffer_state /= "Empty")` (under WF) | no counter-example found | `tlc_runs/dispatch.log` |
| `non_interfere.tla` | Tokens={t1,t2}, MaxTraceLen=3, MaxDraftLen=2 | 252 | `NonInterference` (safety) | no counter-example found | `tlc_runs/non_interfere.log` |

Liveness coverage: only `dispatch.tla`'s `Liveness` survived as a
checked liveness property. `non_interfere.tla`'s `Termination` was
dropped (see notes). The original `dispatch.tla` `DeadlockFree` was
removed because it was malformed (false in Init).

Parse-fail evidence (kept as committed evidence per Rule 1):
- `tlc_runs/rollback.parse-fail.log`
- `tlc_runs/dispatch.parse-fail.log`
- `tlc_runs/non_interfere.unbounded-fail.log`

---

## Deferred findings (for Track R / blog)

1. **`phase4_2_validation_critique.md:35` is demonstrably false**
   against the shipped artefacts. The shipped `non_interfere.tla` +
   shipped `non_interfere.cfg` triggers TLC's
   non-enumerable-quantifier-bound error before any state is
   generated. Any claim that the model checker "successfully explores
   the state space" was not produced by running TLC on the shipped
   files. Track R must rewrite this report.

2. **`NonInterference` is structurally weaker than the OVERVIEW
   claim.** OVERVIEW says drafter "cannot bias the target
   distribution"; the spec proves prefix-equality against a fixed
   sequence. There is no notion of probability, sampling, or
   distribution in the model. The right title is
   "speculative-decoding prefix correctness", not "non-interference
   of drafter on target distribution".

3. **`dispatch.tla`'s `DeadlockFree` was malformed (false in Init)**.
   Any prior claim of "Safety proof for asynchronous NPU offloading"
   that included DeadlockFree could not have been backed by a TLC
   run, because such a run would have failed at the initial state.
   Either the run wasn't done, or it wasn't on this property. Track
   R should remove or qualify the safety-proof phrasing in OVERVIEW.

4. **All three TLA+ artefacts are tiny finite checks** (4, 31, 252
   reachable states). They are protocol skeletons, not system-level
   proofs. The blog must classify them as Tier 2 (bounded-checked)
   per `REMEDIATION_PLAN.md`'s evidence pyramid, not as proofs.

5. **`rollback.tla`'s most useful artefact is the unsafe
   counter-example**, not the safe-spec green run. The
   counter-example shows that the SafeRollback guard is load-bearing.
   This pair-of-runs comparison is what the blog should highlight
   for Tier 2 evidence; the safe spec alone is borderline vanity.

6. **No fairness story for `non_interfere.tla`'s liveness.**
   `Termination` cannot be salvaged with TLC's WF semantics on
   existentially-quantified actions. A real liveness claim for
   speculative decoding would require a deterministic-drafter
   scheduler model, which is a different paper.
