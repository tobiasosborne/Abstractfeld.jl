import Mathlib.Data.Rat.Defs

namespace Abstractfeld.IR

/-- Index position: contravariant (up) or covariant (down). -/
inductive IndexPos where
  | up
  | down
deriving DecidableEq, Repr, Hashable, Inhabited

/-- Annotation on an expression. -/
inductive Annotation where
  | symmetry (kind : String) (slots : List Nat)
  | typeAnn (tag : String)
deriving DecidableEq, Repr, Inhabited

/-- The unified IR for Abstractfeld. Mirrors the Julia types exactly. -/
inductive Expr where
  | lit (val : ℚ)
  | sym (name : String)
  | idx (name : String) (pos : IndexPos)
  | app (op : String) (args : List Expr)
  | bind (binder : String) (var : Expr) (body : Expr) (metadata : List Expr)
  | ann (expr : Expr) (annot : Annotation)
deriving Repr, Inhabited

/-- Size of an expression (number of nodes). -/
def Expr.size : Expr → Nat
  | .lit _ => 1
  | .sym _ => 1
  | .idx _ _ => 1
  | .app _ args => 1 + args.foldl (fun acc a => acc + a.size) 0
  | .bind _ var body metadata => 1 + var.size + body.size + metadata.foldl (fun acc m => acc + m.size) 0
  | .ann e _ => 1 + e.size

/-- Depth of an expression. -/
def Expr.depth : Expr → Nat
  | .lit _ => 1
  | .sym _ => 1
  | .idx _ _ => 1
  | .app _ args => 1 + (args.map Expr.depth |>.foldl max 0)
  | .bind _ var body metadata =>
    1 + max var.depth (max body.depth (metadata.map Expr.depth |>.foldl max 0))
  | .ann e _ => 1 + e.depth

end Abstractfeld.IR
