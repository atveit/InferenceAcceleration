/-
  G4FlashTreeTheory.TQTopo — quantization preserves inner products
  up to a Cauchy–Schwarz bound.

  What this file proves (in plain English):

    Let `V` be any real inner-product space (`InnerProductSpace ℝ V`).
    Let `T : V → V` be any function (the quantization-and-dequantization
    composition; we make NO algebraic assumptions on `T` — it need not
    be linear, isometric, or even continuous). Suppose for some `η ≥ 0`
    we have `‖T z − z‖ ≤ η · ‖z‖` for every `z : V`. Then for all
    `x, y : V`,

        |⟨x, y⟩ − ⟨T x, T y⟩|  ≤  2 η ‖x‖ ‖y‖ + η² ‖x‖ ‖y‖.

    Proof is straight Cauchy–Schwarz on the three cross-terms after
    expanding `⟨x + δx, y + δy⟩` with `δx = T x − x`, `δy = T y − y`.

  What this file does NOT prove:

    1. Anything specific to **TurboQuant**. TurboQuant uses a Hadamard
       rotation followed by per-block quantization; its actual
       distortion bound is `O(d^{-1/2})` per the original paper. The
       theorem here only uses the *interface* `‖T z − z‖ ≤ η ‖z‖`. So
       this is a generic Lipschitz-perturbation bound; it relates the
       runtime quantizer to the classical Cauchy–Schwarz inequality
       *only modulo* a separately-justified Lipschitz constant `η`.

    2. **Anything about IEEE-754 floats.** Same caveat as elsewhere.
       Real inner products are exact in `ℝ`; bf16/fp16 inner products
       are not. The η bound here ignores rounding error in the inner
       product itself.

    3. The `error_bound η x y := 2η‖x‖‖y‖ + η²‖x‖‖y‖` is **linear in
       the magnitudes**. The original `tq_topo.lean` had `error_bound
       := η`, which is wrong as a bound (it does not scale). This is
       the substantive correction.

  The original `IsOrderedRing` typeclass, the `def abs := sorry`, and
  the missing `Sub` are all replaced by Mathlib's `InnerProductSpace`,
  whose `Inner`, `norm`, and `Cauchy–Schwarz` are already in scope.
-/

import Mathlib.Analysis.InnerProductSpace.Basic

namespace G4FlashTreeTheory.TQTopo

open scoped InnerProductSpace

variable {V : Type*} [NormedAddCommGroup V] [InnerProductSpace ℝ V]

/-- Quantization-error bound, scaled by the input magnitudes. -/
def errorBound (η : ℝ) (x y : V) : ℝ :=
  2 * η * ‖x‖ * ‖y‖ + η * η * ‖x‖ * ‖y‖

/--
  **Headline.** If `T` perturbs every input by at most `η ‖·‖` in
  norm, then `T` preserves real inner products up to `errorBound η`.
  No linearity, isometry, or continuity assumption on `T`.
-/
theorem tq_homomorphism_bound
    (T : V → V) (η : ℝ) (hη : 0 ≤ η)
    (hT : ∀ z : V, ‖T z - z‖ ≤ η * ‖z‖)
    (x y : V) :
    |⟪x, y⟫_ℝ - ⟪T x, T y⟫_ℝ| ≤ errorBound η x y := by
  -- Let δx = T x − x, δy = T y − y.
  set δx : V := T x - x with hδx
  set δy : V := T y - y with hδy
  -- T x = x + δx, T y = y + δy
  have hTx : T x = x + δx := by simp [hδx]
  have hTy : T y = y + δy := by simp [hδy]
  -- Expand ⟨T x, T y⟩.
  have hexpand :
      ⟪T x, T y⟫_ℝ
        = ⟪x, y⟫_ℝ + ⟪x, δy⟫_ℝ + ⟪δx, y⟫_ℝ + ⟪δx, δy⟫_ℝ := by
    rw [hTx, hTy]
    rw [inner_add_left, inner_add_right, inner_add_right]
    ring
  -- So the difference is exactly the three cross-terms.
  have hdiff :
      ⟪x, y⟫_ℝ - ⟪T x, T y⟫_ℝ
        = -(⟪x, δy⟫_ℝ + ⟪δx, y⟫_ℝ + ⟪δx, δy⟫_ℝ) := by
    rw [hexpand]; ring
  -- Bound each cross-term by Cauchy–Schwarz.
  have hCS_xδy : |⟪x, δy⟫_ℝ| ≤ ‖x‖ * ‖δy‖ := by
    exact abs_real_inner_le_norm x δy
  have hCS_δxy : |⟪δx, y⟫_ℝ| ≤ ‖δx‖ * ‖y‖ := by
    exact abs_real_inner_le_norm δx y
  have hCS_δxδy : |⟪δx, δy⟫_ℝ| ≤ ‖δx‖ * ‖δy‖ := by
    exact abs_real_inner_le_norm δx δy
  -- Use the Lipschitz bound on T.
  have hδx_norm : ‖δx‖ ≤ η * ‖x‖ := by
    rw [hδx]; exact hT x
  have hδy_norm : ‖δy‖ ≤ η * ‖y‖ := by
    rw [hδy]; exact hT y
  -- Norms are nonneg.
  have hnx : (0 : ℝ) ≤ ‖x‖ := norm_nonneg _
  have hny : (0 : ℝ) ≤ ‖y‖ := norm_nonneg _
  have hδx_nn : (0 : ℝ) ≤ ‖δx‖ := norm_nonneg _
  have hδy_nn : (0 : ℝ) ≤ ‖δy‖ := norm_nonneg _
  -- Combine via triangle inequality on |·|.
  have htri :
      |⟪x, y⟫_ℝ - ⟪T x, T y⟫_ℝ|
        ≤ |⟪x, δy⟫_ℝ| + |⟪δx, y⟫_ℝ| + |⟪δx, δy⟫_ℝ| := by
    rw [hdiff, abs_neg]
    have ha := abs_add_le (⟪x, δy⟫_ℝ + ⟪δx, y⟫_ℝ) ⟪δx, δy⟫_ℝ
    have hb := abs_add_le ⟪x, δy⟫_ℝ ⟪δx, y⟫_ℝ
    linarith
  -- Now stitch together.
  have h1 : ‖x‖ * ‖δy‖ ≤ ‖x‖ * (η * ‖y‖) :=
    mul_le_mul_of_nonneg_left hδy_norm hnx
  have h2 : ‖δx‖ * ‖y‖ ≤ (η * ‖x‖) * ‖y‖ :=
    mul_le_mul_of_nonneg_right hδx_norm hny
  have h3 : ‖δx‖ * ‖δy‖ ≤ (η * ‖x‖) * (η * ‖y‖) :=
    mul_le_mul hδx_norm hδy_norm hδy_nn (by positivity)
  -- Final calc.
  unfold errorBound
  have step1 :
      |⟪x, δy⟫_ℝ| + |⟪δx, y⟫_ℝ| + |⟪δx, δy⟫_ℝ|
        ≤ ‖x‖ * (η * ‖y‖) + (η * ‖x‖) * ‖y‖ + (η * ‖x‖) * (η * ‖y‖) := by
    have q1 : |⟪x, δy⟫_ℝ| ≤ ‖x‖ * (η * ‖y‖) := le_trans hCS_xδy h1
    have q2 : |⟪δx, y⟫_ℝ| ≤ (η * ‖x‖) * ‖y‖ := le_trans hCS_δxy h2
    have q3 : |⟪δx, δy⟫_ℝ| ≤ (η * ‖x‖) * (η * ‖y‖) := le_trans hCS_δxδy h3
    linarith
  calc |⟪x, y⟫_ℝ - ⟪T x, T y⟫_ℝ|
      ≤ |⟪x, δy⟫_ℝ| + |⟪δx, y⟫_ℝ| + |⟪δx, δy⟫_ℝ| := htri
    _ ≤ ‖x‖ * (η * ‖y‖) + (η * ‖x‖) * ‖y‖ + (η * ‖x‖) * (η * ‖y‖) := step1
    _ = 2 * η * ‖x‖ * ‖y‖ + η * η * ‖x‖ * ‖y‖ := by ring

end G4FlashTreeTheory.TQTopo
