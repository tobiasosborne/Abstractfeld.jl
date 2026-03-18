/-
  Abstractfeld.Tensor.Interpret
  Semantic interpretation: maps IR expressions to Mathlib AlternatingMap.
  This gives the IR mathematical meaning — without it, proofs are syntax games.
-/
import Abstractfeld.IR.Expr
import Mathlib.LinearAlgebra.Alternating.Basic

namespace Abstractfeld.Tensor

open Abstractfeld.IR

/-- Environment mapping symbol names to alternating maps. -/
abbrev Env (M : Type*) [AddCommGroup M] [Module ℚ M] (k : ℕ) :=
  String → AlternatingMap ℚ M ℚ (Fin k)

variable {M : Type*} [AddCommGroup M] [Module ℚ M] {k : ℕ}

/-- Evaluate an IR expression as an alternating map.
    Supported: sym (lookup), + (addition), neg (negation), * (scalar mult), lit (zero). -/
noncomputable def eval (Γ : Env M k) : Expr → AlternatingMap ℚ M ℚ (Fin k)
  | .sym name => Γ name
  | .app "+" [e1, e2] => eval Γ e1 + eval Γ e2
  | .app "neg" [e] => -(eval Γ e)
  | .app "*" [.lit q, e] => q • eval Γ e
  | .lit _ => 0
  | _ => 0

-- simp lemmas for unfolding eval in proofs
@[simp] theorem eval_sym (Γ : Env M k) (name : String) :
    eval Γ (.sym name) = Γ name := rfl

@[simp] theorem eval_add (Γ : Env M k) (e1 e2 : Expr) :
    eval Γ (.app "+" [e1, e2]) = eval Γ e1 + eval Γ e2 := rfl

@[simp] theorem eval_neg (Γ : Env M k) (e : Expr) :
    eval Γ (.app "neg" [e]) = -(eval Γ e) := rfl

@[simp] theorem eval_smul (Γ : Env M k) (q : ℚ) (e : Expr) :
    eval Γ (.app "*" [.lit q, e]) = q • eval Γ e := rfl

-- Foundational AlternatingMap theorems (thin wrappers for z4c)

/-- Swapping two arguments of an alternating map negates the result. -/
theorem altMap_swap_neg [DecidableEq (Fin k)] (f : AlternatingMap ℚ M ℚ (Fin k))
    (v : Fin k → M) {i j : Fin k} (hij : i ≠ j) :
    f (v ∘ Equiv.swap i j) = -(f v) :=
  f.map_swap v hij

/-- An alternating map plus its swap is zero. -/
theorem altMap_swap_cancel [DecidableEq (Fin k)] (f : AlternatingMap ℚ M ℚ (Fin k))
    (v : Fin k → M) {i j : Fin k} (hij : i ≠ j) :
    f v + f (v ∘ Equiv.swap i j) = 0 :=
  f.map_add_swap v hij

end Abstractfeld.Tensor
