/-
  Abstractfeld.Tensor.Identities
  Core tensor identity theorems — axiom-free, sorry-free.
  All proofs backed by Mathlib's AlternatingMap foundations.
-/
import Abstractfeld.Tensor.Interpret

namespace Abstractfeld.Tensor

open Abstractfeld.IR

variable {M : Type*} [AddCommGroup M] [Module ℚ M]

/-! ## Antisymmetry theorems -/

/-- Antisymmetry: swapping any two indices of an alternating map negates it. -/
theorem antisym_swap {k : ℕ} (f : AlternatingMap ℚ M ℚ (Fin k)) (v : Fin k → M)
    {i j : Fin k} (hij : i ≠ j) :
    f (v ∘ Equiv.swap i j) = -(f v) :=
  f.map_swap v hij

/-- First-pair antisymmetry for rank-4 tensors: R_{abcd} = -R_{bacd}. -/
theorem first_pair_antisym (f : AlternatingMap ℚ M ℚ (Fin 4)) (v : Fin 4 → M) :
    f (v ∘ Equiv.swap 0 1) = -(f v) :=
  f.map_swap v (by decide)

/-- Last-pair antisymmetry for rank-4 tensors: R_{abcd} = -R_{abdc}. -/
theorem last_pair_antisym (f : AlternatingMap ℚ M ℚ (Fin 4)) (v : Fin 4 → M) :
    f (v ∘ Equiv.swap 2 3) = -(f v) :=
  f.map_swap v (by decide)

/-! ## Block symmetry -/

/-- Block symmetry for rank-4 tensors: R_{abcd} = R_{cdab}.
    The permutation (0↔2)(1↔3) is even, so it preserves the alternating map. -/
theorem block_sym (f : AlternatingMap ℚ M ℚ (Fin 4)) (v : Fin 4 → M) :
    let σ : Equiv.Perm (Fin 4) := Equiv.swap 0 2 * Equiv.swap 1 3
    f (v ∘ σ) = f v := by
  intro σ
  have h := f.map_perm v σ
  rw [h]
  have hsign : σ.sign = 1 := by decide
  rw [hsign, one_smul]

/-! ## Cancellation -/

/-- An alternating map plus its swap is zero. -/
theorem swap_cancel {k : ℕ} (f : AlternatingMap ℚ M ℚ (Fin k)) (v : Fin k → M)
    {i j : Fin k} (hij : i ≠ j) :
    f v + f (v ∘ Equiv.swap i j) = 0 :=
  f.map_add_swap v hij

/-! ## Connection to eval — IR-level identity verification -/

/-- If two symbols evaluate to negatives, their IR sum evaluates to zero. -/
theorem eval_antisym_cancel {k : ℕ} (Γ : Env M k) (a b : String)
    (h : Γ b = -(Γ a)) :
    eval Γ (.app "+" [.sym a, .sym b]) = 0 := by
  simp [h, add_neg_cancel]

end Abstractfeld.Tensor
