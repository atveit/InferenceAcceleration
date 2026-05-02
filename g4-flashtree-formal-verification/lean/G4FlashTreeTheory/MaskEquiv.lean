/-
  G4FlashTreeTheory.MaskEquiv — Tree-attention vs path-attention.

  What this file proves (in plain English):

    1. (Set-level) For any tree `T` whose `parent` map is strictly
       decreasing in index, the *set of ancestors* of node `i` equals
       the set `{ j ∈ {0,...,i} | is_ancestor T j i }`. So filtering a
       sum over `List.range (i+1)` by `is_ancestor` and filtering by
       `j ≤ i ∧ is_ancestor` give the same list. (This was already in
       the original `mask_equiv.lean`.)

    2. (Real, softmax-level) Let `score : Nat → ℝ` be raw attention
       scores and `mask : Nat → Bool` zero out non-ancestors. The
       softmax normalizer computed over `List.range (i+1)` while
       restricting the support to ancestors via `mask` equals the
       softmax normalizer computed only over the ancestor list. As a
       corollary, the masked softmax-attention output (numerator over
       ancestors / denominator over ancestors) equals the path-attention
       softmax output. This is the load-bearing statement for "tree
       mask = path mask" in real attention, and it is the gap the
       original audit flagged.

  What this file does NOT prove:

    • Anything about IEEE-754 softmax. The proof is over `ℝ`. Real
      softmax in Gemma 4 runs in fp16/bf16 with rounding error and
      saturating exponentials. The cited bound is exact only in
      ℝ-arithmetic.
    • Anything about Gemma 4's specific mask layout (sliding-window
      vs full-causal). The tree here is an abstract `parent : Nat → Nat`
      with `parent i < i` for `i > 0`.
    • Anything about how tree-masked decoding relates to MLX/Metal
      kernel implementations. That is engineering, not theorem.
-/

import Mathlib.Data.List.Basic
import Mathlib.Data.List.Range
import Mathlib.Data.Real.Basic
import Mathlib.Analysis.SpecialFunctions.Exp

namespace G4FlashTreeTheory.MaskEquiv

/--
  A `Tree` is given by a parent function and a strict-decrease invariant.
  This is enough structure to define ancestry by well-founded recursion
  on the index.
-/
structure Tree where
  parent : Nat → Nat
  p_lt   : ∀ i, 0 < i → parent i < i

/--
  `is_ancestor T j i` is `true` iff `j` is `i` itself or an ancestor of
  `i` reachable by repeatedly following `T.parent`.
-/
def is_ancestor (T : Tree) (j i : Nat) : Bool :=
  if i = j then
    true
  else if h0 : i = 0 then
    false
  else
    have : T.parent i < i := T.p_lt i (Nat.pos_of_ne_zero h0)
    is_ancestor T j (T.parent i)
termination_by i

/--
  Any ancestor index is `≤` the descendant. Genuine induction on `i`
  using the strict-decrease invariant.
-/
theorem ancestor_le (T : Tree) {j i : Nat} :
    is_ancestor T j i = true → j ≤ i := by
  induction i using Nat.strong_induction_on with
  | _ i ih =>
    intro h
    unfold is_ancestor at h
    split at h
    · next h_eq => simp [h_eq]
    · split at h
      · next _ h_zero => simp at h
      · next _ h_not_zero =>
        have h_pos : 0 < i := Nat.pos_of_ne_zero h_not_zero
        have h_p := T.p_lt i h_pos
        exact Nat.le_trans (ih (T.parent i) h_p h) (Nat.le_of_lt h_p)

/-- The ancestor list of `i`: indices `j ≤ i` that are ancestors. -/
def ancestorList (T : Tree) (i : Nat) : List Nat :=
  ((List.range (i + 1)).filter (fun j => is_ancestor T j i))

/-- The path list of `i`: explicitly imposes `j ≤ i` *and* `is_ancestor`. -/
def pathList (T : Tree) (i : Nat) : List Nat :=
  ((List.range (i + 1)).filter (fun j => decide (j ≤ i) && is_ancestor T j i))

/--
  Set-level equivalence: ancestor-filter and path-filter give the same
  list. Inside `List.range (i+1)` every `j` already satisfies `j ≤ i`,
  so the extra `j ≤ i` predicate is redundant. This is the lemma the
  original `mask_equiv.lean` proved.
-/
theorem ancestor_eq_path (T : Tree) (i : Nat) :
    ancestorList T i = pathList T i := by
  unfold ancestorList pathList
  apply List.filter_congr
  intro j hj
  have h_in_range : j < i + 1 := List.mem_range.mp hj
  have h_le_i : j ≤ i := Nat.le_of_lt_succ h_in_range
  simp [h_le_i]

/--
  Causal soundness over a `Nat`-valued sum: if two score functions
  agree on every ancestor of `i`, their sums over the ancestor list
  agree. (The original `causal_soundness`.)
-/
theorem causal_soundness_nat (T : Tree) (f g : Nat → Nat) (i : Nat)
    (h_eq : ∀ j, is_ancestor T j i = true → f j = g j) :
    ((ancestorList T i).map f).foldl (· + ·) 0 =
    ((ancestorList T i).map g).foldl (· + ·) 0 := by
  unfold ancestorList
  congr 1
  apply List.map_congr_left
  intro j hj
  have hj' := List.mem_filter.mp hj
  exact h_eq j hj'.2

/-! ## Softmax-level equivalence (the strengthened claim)

The original audit's MAJOR finding on `mask_equiv.lean`: the proof
operates over `Nat`-sums, but real attention uses softmax — so the
"tree mask equals path mask" claim was set-theoretic, not numerical.
We close that gap here over `ℝ`.

Given:
  • `score : Nat → ℝ`  (raw QKᵀ scores)
  • `i : Nat`           (the query position)
  • `T : Tree`           (the speculative tree)

Define two attention schemes:

  • `treeSoftmax T score i`:
      numerator   = Σ_{j ∈ range(i+1)} indic(is_ancestor T j i) · exp(score j) · score j
      denominator = Σ_{j ∈ range(i+1)} indic(is_ancestor T j i) · exp(score j)

  • `pathSoftmax T score i`:
      numerator   = Σ_{j ∈ ancestorList T i}                                 exp(score j) · score j
      denominator = Σ_{j ∈ ancestorList T i}                                 exp(score j)

We prove the numerators and denominators are *pointwise* equal (as
real-number sums), so the softmax outputs coincide whenever the
denominator is positive.
-/

open Real

/-- Sum a real-valued function over a list. -/
def listSum (l : List Nat) (f : Nat → ℝ) : ℝ :=
  (l.map f).foldr (· + ·) 0

@[simp] theorem listSum_nil (f : Nat → ℝ) : listSum [] f = 0 := rfl

@[simp] theorem listSum_cons (a : Nat) (l : List Nat) (f : Nat → ℝ) :
    listSum (a :: l) f = f a + listSum l f := rfl

/--
  Filtering a list before summing is the same as multiplying each
  term by an indicator. (Real-valued analogue of mask-zeroing.)
-/
theorem listSum_filter_eq_mul_indicator (l : List Nat)
    (p : Nat → Bool) (f : Nat → ℝ) :
    listSum (l.filter p) f =
    listSum l (fun j => if p j then f j else 0) := by
  induction l with
  | nil => simp
  | cons a l ih =>
    by_cases h : p a
    · simp [h, ih]
    · simp [h, ih]

/-- Tree-mask softmax denominator. -/
noncomputable def treeDenom (T : Tree) (score : Nat → ℝ) (i : Nat) : ℝ :=
  listSum (List.range (i + 1))
    (fun j => if is_ancestor T j i then Real.exp (score j) else 0)

/-- Tree-mask softmax numerator (weighted by `score j`). -/
noncomputable def treeNumer (T : Tree) (score : Nat → ℝ) (i : Nat) : ℝ :=
  listSum (List.range (i + 1))
    (fun j => if is_ancestor T j i then Real.exp (score j) * score j else 0)

/-- Path-attention denominator: sum directly over ancestor list. -/
noncomputable def pathDenom (T : Tree) (score : Nat → ℝ) (i : Nat) : ℝ :=
  listSum (ancestorList T i) (fun j => Real.exp (score j))

/-- Path-attention numerator. -/
noncomputable def pathNumer (T : Tree) (score : Nat → ℝ) (i : Nat) : ℝ :=
  listSum (ancestorList T i) (fun j => Real.exp (score j) * score j)

/--
  **Headline:** the tree-mask softmax denominator equals the
  path-softmax denominator.
-/
theorem tree_eq_path_denom (T : Tree) (score : Nat → ℝ) (i : Nat) :
    treeDenom T score i = pathDenom T score i := by
  unfold treeDenom pathDenom ancestorList
  rw [listSum_filter_eq_mul_indicator]

/-- Same for the numerator. -/
theorem tree_eq_path_numer (T : Tree) (score : Nat → ℝ) (i : Nat) :
    treeNumer T score i = pathNumer T score i := by
  unfold treeNumer pathNumer ancestorList
  rw [listSum_filter_eq_mul_indicator]

/--
  **Corollary (softmax output equality):** when the denominator is
  nonzero (always true since `exp > 0` and at least `i` itself is an
  ancestor of `i`), the tree-mask softmax-weighted average equals the
  path-softmax weighted average.
-/
theorem tree_eq_path_softmax
    (T : Tree) (score : Nat → ℝ) (i : Nat)
    (_h : pathDenom T score i ≠ 0) :
    treeNumer T score i / treeDenom T score i =
    pathNumer T score i / pathDenom T score i := by
  rw [tree_eq_path_numer, tree_eq_path_denom]

/-! ## Sanity: the denominator is in fact strictly positive

A query token is an ancestor of itself, so the ancestor list is
non-empty and every term `exp (score j)` is positive. This rules out
division-by-zero in the corollary above.
-/

theorem self_is_ancestor (T : Tree) (i : Nat) :
    is_ancestor T i i = true := by
  unfold is_ancestor
  simp

theorem self_mem_range_succ (i : Nat) : i ∈ List.range (i + 1) := by
  exact List.mem_range.mpr (Nat.lt_succ_self i)

theorem self_mem_ancestorList (T : Tree) (i : Nat) :
    i ∈ ancestorList T i := by
  unfold ancestorList
  rw [List.mem_filter]
  exact ⟨self_mem_range_succ i, self_is_ancestor T i⟩

theorem pathDenom_pos (T : Tree) (score : Nat → ℝ) (i : Nat) :
    0 < pathDenom T score i := by
  unfold pathDenom listSum
  -- every term is strictly positive (exp > 0); we only need positivity
  -- of one term, namely the self-ancestor.
  have h_self : i ∈ ancestorList T i := self_mem_ancestorList T i
  -- Strategy: rewrite the foldr-sum as a List.sum, then bound below
  -- by a single term.
  have hsum_pos :
      ∀ (l : List Nat), i ∈ l →
        0 < ((l.map (fun j => Real.exp (score j))).foldr (· + ·) 0) := by
    intro l hi_mem
    induction l with
    | nil => simp at hi_mem
    | cons a l ih =>
      simp only [List.map_cons, List.foldr_cons]
      rcases List.mem_cons.mp hi_mem with rfl | h_tail
      · -- head case: positive head + nonneg tail
        have : 0 ≤ ((l.map (fun j => Real.exp (score j))).foldr (· + ·) 0) := by
          clear ih hi_mem
          induction l with
          | nil => simp
          | cons b l ih2 =>
            simp only [List.map_cons, List.foldr_cons]
            have hb : 0 ≤ Real.exp (score b) := (Real.exp_pos _).le
            linarith
        have hh : 0 < Real.exp (score i) := Real.exp_pos _
        linarith
      · have hpos := ih h_tail
        have ha : 0 ≤ Real.exp (score a) := (Real.exp_pos _).le
        linarith
  exact hsum_pos _ h_self

/--
  Putting it all together: the tree-mask softmax denominator is
  strictly positive, hence division is well-defined and the
  tree-attention output equals the path-attention output for that
  query.
-/
theorem tree_eq_path_softmax_total
    (T : Tree) (score : Nat → ℝ) (i : Nat) :
    treeNumer T score i / treeDenom T score i =
    pathNumer T score i / pathDenom T score i := by
  have h_pos := pathDenom_pos T score i
  exact tree_eq_path_softmax T score i (ne_of_gt h_pos)

end G4FlashTreeTheory.MaskEquiv
