/-
  G4FlashTreeTheory.RopeId — 2D rotation preserves dot product.

  What this file proves (in plain English):

    Over any commutative ring `R`, given `cosθ, sinθ : R` satisfying
    the algebraic Pythagorean identity `cosθ² + sinθ² = 1`, the linear
    map `(x,y) ↦ (x·cosθ − y·sinθ, x·sinθ + y·cosθ)` preserves the
    bilinear form `⟨v, w⟩ := v.x·w.x + v.y·w.y`.

    This is the textbook 2D rotation lemma. It is the *only* algebraic
    fact about rotations that the original `rope_id.lean` author tried
    to capture. We discharge it cleanly with Mathlib's `ring` tactic
    (which the original file lacked because it rolled its own
    `IsCommRing` typeclass).

  What this file does NOT prove:

    1. Anything specific to **p-RoPE** (proportional RoPE). The "p" in
       p-RoPE refers to a frequency-scaling parameter λ in the choice
       of `θ_m = m · base^(−2k/d) / λ`. The identity proven here
       depends only on `cosθ² + sinθ² = 1`; it is *agnostic* to how θ
       is generated. So this is the standard rotation fact, not a
       p-RoPE-specific theorem. We keep a `pRoPE` definition only to
       make that lack of specificity explicit.

    2. **Anything about IEEE-754 floats.** `ℝ` and abstract commutative
       rings are exact. Real GPU/ANE arithmetic uses bf16/fp16 which
       is *not* a commutative ring (no associativity, denormals,
       saturation, rounding). The dot-product preservation is exact
       in `R`; in floats it holds up to a backward-stable error of
       order `O(d · ε_mach)`. That bound is not formalized here.

    3. **Anything about `cos`/`sin` of actual angles.** We take the
       Pythagorean identity as a hypothesis. Whether `Real.cos` and
       `Real.sin` satisfy it is a Mathlib lemma we cite only as a
       sanity check below; we do not prove it here.
-/

import Mathlib.Algebra.Ring.Basic
import Mathlib.Tactic.Ring
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic

namespace G4FlashTreeTheory.RopeId

variable {R : Type*} [CommRing R]

/-- A 2D vector over a commutative ring. -/
structure Vector2 (R : Type*) where
  x : R
  y : R

/-- The standard symmetric bilinear form on `Vector2 R`. -/
def dot (a b : Vector2 R) : R :=
  a.x * b.x + a.y * b.y

/-- The standard 2D rotation parametrised by a `(cos, sin)` pair. -/
def rotate (v : Vector2 R) (cosθ sinθ : R) : Vector2 R :=
  { x := v.x * cosθ - v.y * sinθ
  , y := v.x * sinθ + v.y * cosθ }

/--
  **Headline (no `sorry`).** Over any commutative ring, the rotation
  map preserves `dot` whenever the parameters satisfy `c² + s² = 1`.
-/
theorem rotation_preserves_dot
    (v w : Vector2 R) (cosθ sinθ : R)
    (h_pythag : cosθ * cosθ + sinθ * sinθ = 1) :
    dot (rotate v cosθ sinθ) (rotate w cosθ sinθ) = dot v w := by
  unfold dot rotate
  -- Goal: (v.x*c - v.y*s)*(w.x*c - w.y*s) + (v.x*s + v.y*c)*(w.x*s + w.y*c)
  --     = v.x*w.x + v.y*w.y
  -- Expand on both sides; the cross-terms cancel and the diagonal
  -- terms factor through `c² + s² = 1`.
  have h := h_pythag
  ring_nf
  linear_combination (v.x * w.x + v.y * w.y) * h

/--
  Generic p-RoPE rotation: simply applies `rotate` at the scaled
  angle `m_freq_scaled`. The "p" (proportional) frequency-scaling λ
  is *encoded in how the caller computes `m_freq_scaled` from `m`*.
  This definition deliberately makes no algebraic use of λ — to flag
  that the identity below holds for any choice of (cos, sin) functions
  satisfying the Pythagorean identity pointwise.
-/
def pRoPE (v : Vector2 R) (m_freq_scaled : R)
    (cos_fn sin_fn : R → R) : Vector2 R :=
  rotate v (cos_fn m_freq_scaled) (sin_fn m_freq_scaled)

/--
  **Corollary.** Any p-RoPE-shaped rotation preserves `dot` provided
  the underlying `(cos_fn, sin_fn)` satisfies the Pythagorean identity
  at the chosen angle.
-/
theorem rope_rotational_identity
    (v w : Vector2 R) (m_freq_scaled : R)
    (cos_fn sin_fn : R → R)
    (h_trig : ∀ θ, cos_fn θ * cos_fn θ + sin_fn θ * sin_fn θ = 1) :
    dot (pRoPE v m_freq_scaled cos_fn sin_fn)
        (pRoPE w m_freq_scaled cos_fn sin_fn) = dot v w := by
  unfold pRoPE
  exact rotation_preserves_dot v w
    (cos_fn m_freq_scaled) (sin_fn m_freq_scaled)
    (h_trig m_freq_scaled)

/--
  Sanity instance: `Real.cos` and `Real.sin` satisfy the Pythagorean
  identity, so the corollary above specialises to `ℝ`. This is not a
  separate proof obligation; it just shows the abstract result is
  applicable to `ℝ` in principle. (It is *not* applicable to fp16/bf16
  in practice.)
-/
example (m : ℝ) (v w : Vector2 ℝ) :
    dot (pRoPE v m Real.cos Real.sin) (pRoPE w m Real.cos Real.sin) =
    dot v w :=
  rope_rotational_identity v w m Real.cos Real.sin
    (fun θ => by
      have := Real.sin_sq_add_cos_sq θ
      -- sin² + cos² = 1, rearranged as cos*cos + sin*sin = 1
      nlinarith [Real.sin_sq_add_cos_sq θ])

end G4FlashTreeTheory.RopeId
