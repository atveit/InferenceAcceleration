/-
  G4FlashTreeTheory.AttnIso — sliding-window attention zero-leakage.

  What this file proves (in plain English):

    The original `attn_iso.lean` claimed "SWA / Global Boundary"
    over a model of *unweighted integer sums*, i.e. it ignored the
    softmax normalizer entirely. We restate the property at the
    softmax level over `ℝ`:

      Let `score : Nat → ℝ` and `value : Nat → ℝ` be raw scores and
      values, and let `M(t, j, W) = (j ≤ t) ∧ (t - j < W)` be the
      causal sliding-window mask of width `W`. Define

        attn(score, value, t, W) :=
          Σ_{j ≤ t, t-j<W} exp(score j) · value j
          ─────────────────────────────────────────
          Σ_{j ≤ t, t-j<W} exp(score j)

    Theorem `swa_zero_leakage_softmax`: if two score-and-value pairs
    `(score₁, value₁)`, `(score₂, value₂)` agree on every `j` inside
    the window at position `t`, then `attn` outputs the same real
    number. In particular, perturbing a token *outside* the window
    has zero effect on the output at `t`.

  What this file does NOT prove:

    1. Anything about the **interaction** between SWA layers and global
       layers in Gemma 4 (the 5-of-6 pattern). The audit flagged that
       the original "SWA / Global Boundary" claim implicitly required
       the joint behaviour of the two layer types; this file only
       covers the SWA half in isolation. That is the honest scope.

    2. Anything about a real Q/K/V projection. `score` here is an
       arbitrary `Nat → ℝ`. The theorem applies *whatever* upstream
       computation produced `score`; it does not say anything about
       how Q/K interact.

    3. Anything about IEEE-754 softmax. Same caveat as RopeId: real
       softmax in fp16/bf16 has rounding error that this proof does
       not bound.
-/

import Mathlib.Data.List.Basic
import Mathlib.Data.List.Range
import Mathlib.Data.Real.Basic
import Mathlib.Analysis.SpecialFunctions.Exp

namespace G4FlashTreeTheory.AttnIso

open Real

/-- The causal sliding-window mask predicate. -/
def swaMask (t j W : Nat) : Bool :=
  decide (j ≤ t) && decide (t - j < W)

/-- Sum a real-valued function over a list. -/
def listSum (l : List Nat) (f : Nat → ℝ) : ℝ :=
  (l.map f).foldr (· + ·) 0

@[simp] theorem listSum_nil (f : Nat → ℝ) : listSum [] f = 0 := rfl

@[simp] theorem listSum_cons (a : Nat) (l : List Nat) (f : Nat → ℝ) :
    listSum (a :: l) f = f a + listSum l f := rfl

/-- Filtering before summing equals multiplying by an indicator. -/
theorem listSum_filter_eq_indicator (l : List Nat)
    (p : Nat → Bool) (f : Nat → ℝ) :
    listSum (l.filter p) f =
    listSum l (fun j => if p j then f j else 0) := by
  induction l with
  | nil => simp
  | cons a l ih =>
    by_cases h : p a
    · simp [h, ih]
    · simp [h, ih]

/--
  Pointwise congruence: if `f j = g j` whenever `p j` is true, the
  indicator-weighted sums agree.
-/
theorem listSum_indicator_congr (l : List Nat) (p : Nat → Bool)
    (f g : Nat → ℝ)
    (h : ∀ j ∈ l, p j = true → f j = g j) :
    listSum l (fun j => if p j then f j else 0) =
    listSum l (fun j => if p j then g j else 0) := by
  induction l with
  | nil => simp
  | cons a l ih =>
    have h_tail : ∀ j ∈ l, p j = true → f j = g j :=
      fun j hj => h j (List.mem_cons.mpr (Or.inr hj))
    have h_head : p a = true → f a = g a :=
      fun hp => h a (List.mem_cons.mpr (Or.inl rfl)) hp
    by_cases hpa : p a
    · simp [hpa, h_head hpa, ih h_tail]
    · simp [hpa, ih h_tail]

/-- Softmax-attention denominator over the SWA window at position `t`. -/
noncomputable def swaDenom (score : Nat → ℝ) (t W : Nat) : ℝ :=
  listSum (List.range (t + 1))
    (fun j => if swaMask t j W then Real.exp (score j) else 0)

/-- Softmax-attention numerator over the SWA window at position `t`. -/
noncomputable def swaNumer (score value : Nat → ℝ) (t W : Nat) : ℝ :=
  listSum (List.range (t + 1))
    (fun j => if swaMask t j W then Real.exp (score j) * value j else 0)

/-- The SWA softmax-attention output. -/
noncomputable def swaAttn (score value : Nat → ℝ) (t W : Nat) : ℝ :=
  swaNumer score value t W / swaDenom score t W

/--
  **Headline.** If two `(score, value)` pairs agree on every position
  inside the window at `t`, their SWA softmax attentions agree.

  Note that we make no assumption that the score *functions* agree
  outside the window — that is precisely what "zero leakage" means:
  positions outside the window cannot affect the output, regardless
  of what their scores or values are.
-/
theorem swa_zero_leakage_softmax
    (score₁ value₁ score₂ value₂ : Nat → ℝ) (t W : Nat)
    (h_score : ∀ j, swaMask t j W = true → score₁ j = score₂ j)
    (h_value : ∀ j, swaMask t j W = true → value₁ j = value₂ j) :
    swaAttn score₁ value₁ t W = swaAttn score₂ value₂ t W := by
  unfold swaAttn swaNumer swaDenom
  congr 1
  · -- numerators agree
    apply listSum_indicator_congr
    intro j _ hp
    rw [h_score j hp, h_value j hp]
  · -- denominators agree
    apply listSum_indicator_congr
    intro j _ hp
    rw [h_score j hp]

/--
  Sanity corollary: perturbing a single position `j₀` outside the
  window of `t` does not change the SWA output at `t`. The hypothesis
  `j₀` is far past (`t - j₀ ≥ W`) makes the mask false at `j₀`.
-/
theorem swa_independent_of_distant_past
    (score value : Nat → ℝ) (t W j₀ : Nat) (h_far : t - j₀ ≥ W)
    (sval vval : ℝ) :
    swaAttn score value t W =
    swaAttn (fun k => if k = j₀ then sval else score k)
            (fun k => if k = j₀ then vval else value k) t W := by
  apply swa_zero_leakage_softmax
  · -- score equality on the window
    intro j h_mask
    by_cases hjj : j = j₀
    · -- contradiction: j = j₀ is in window but j₀ is far past
      subst hjj
      exfalso
      unfold swaMask at h_mask
      simp at h_mask
      have : t - j < W := h_mask.2
      omega
    · simp [hjj]
  · intro j h_mask
    by_cases hjj : j = j₀
    · subst hjj
      exfalso
      unfold swaMask at h_mask
      simp at h_mask
      have : t - j < W := h_mask.2
      omega
    · simp [hjj]

end G4FlashTreeTheory.AttnIso
