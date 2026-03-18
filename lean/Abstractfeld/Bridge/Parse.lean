/-
  Abstractfeld.Bridge.Parse
  JSON serialization/deserialization for the IR wire format.
  This is the Lean side of the Julia↔Lean bridge.
-/
import Abstractfeld.IR.Expr
import Lean.Data.Json

open Lean (Json ToJson FromJson toJson)
open Abstractfeld.IR

namespace Abstractfeld.Bridge

/-- Parse a rational number from wire format: `"42"` or `"-7//3"`. -/
def parseRatStr (s : String) : Except String ℚ :=
  let parts := s.splitOn "//"
  match parts with
  | [whole] =>
    match whole.toInt? with
    | some n => .ok n
    | none => .error s!"parseRatStr: invalid integer '{s}'"
  | [numStr, denStr] =>
    match numStr.toInt?, denStr.toNat? with
    | some n, some d =>
      if d == 0 then .error s!"parseRatStr: zero denominator in '{s}'"
      else .ok (mkRat n d)
    | _, _ => .error s!"parseRatStr: invalid rational '{s}'"
  | _ => .error s!"parseRatStr: malformed '{s}'"

/-- Serialize a rational to wire format. -/
def ratToStr (q : ℚ) : String :=
  if q.den == 1 then toString q.num
  else s!"{q.num}//{q.den}"

/-- Parse an annotation from JSON. -/
def parseAnnotation (j : Json) : Except String Annotation := do
  let tag ← j.getObjValAs? String "tag"
  match tag with
  | "symmetry" =>
    let kind ← j.getObjValAs? String "kind"
    let slots ← j.getObjValAs? (Array Nat) "slots"
    return .symmetry kind slots.toList
  | "type" =>
    let name ← j.getObjValAs? String "name"
    return .typeAnn name
  | other => throw s!"parseAnnotation: unknown tag '{other}'"

/-- Parse a JSON value into an IR expression. -/
partial def parseExpr (j : Json) : Except String Expr := do
  let tag ← j.getObjValAs? String "tag"
  match tag with
  | "lit" =>
    let valStr ← j.getObjValAs? String "val"
    let q ← parseRatStr valStr
    return .lit q
  | "sym" =>
    let name ← j.getObjValAs? String "name"
    return .sym name
  | "idx" =>
    let name ← j.getObjValAs? String "name"
    let posStr ← j.getObjValAs? String "pos"
    let pos ← match posStr with
      | "up" => pure IndexPos.up
      | "down" => pure IndexPos.down
      | s => throw s!"parseExpr: unknown index position '{s}'"
    return .idx name pos
  | "app" =>
    let op ← j.getObjValAs? String "op"
    let argsJson ← j.getObjValAs? (Array Json) "args"
    let args ← argsJson.toList.mapM parseExpr
    return .app op args
  | "bind" =>
    let binder ← j.getObjValAs? String "binder"
    let varJson ← j.getObjVal? "var"
    let bodyJson ← j.getObjVal? "body"
    let metaJson ← j.getObjValAs? (Array Json) "metadata"
    let var ← parseExpr varJson
    let body ← parseExpr bodyJson
    let metadata ← metaJson.toList.mapM parseExpr
    return .bind binder var body metadata
  | "ann" =>
    let exprJson ← j.getObjVal? "expr"
    let annJson ← j.getObjVal? "ann"
    let expr ← parseExpr exprJson
    let annot ← parseAnnotation annJson
    return .ann expr annot
  | other => throw s!"parseExpr: unknown tag '{other}'"

/-- Serialize an annotation to JSON. -/
def annotToJson : Annotation → Json
  | .symmetry kind slots =>
    .mkObj [("tag", .str "symmetry"), ("kind", .str kind),
            ("slots", toJson slots)]
  | .typeAnn tag =>
    .mkObj [("tag", .str "type"), ("name", .str tag)]

/-- Serialize an IR expression to JSON. -/
partial def exprToJson : Expr → Json
  | .lit q => .mkObj [("tag", .str "lit"), ("val", .str (ratToStr q))]
  | .sym name => .mkObj [("tag", .str "sym"), ("name", .str name)]
  | .idx name pos =>
    let posStr := match pos with | .up => "up" | .down => "down"
    .mkObj [("tag", .str "idx"), ("name", .str name), ("pos", .str posStr)]
  | .app op args =>
    .mkObj [("tag", .str "app"), ("op", .str op),
            ("args", .arr (args.map exprToJson).toArray)]
  | .bind binder var body metadata =>
    .mkObj [("tag", .str "bind"), ("binder", .str binder),
            ("var", exprToJson var), ("body", exprToJson body),
            ("metadata", .arr (metadata.map exprToJson).toArray)]
  | .ann expr annot =>
    .mkObj [("tag", .str "ann"), ("expr", exprToJson expr),
            ("ann", annotToJson annot)]

/-- Convenience: parse an expression from a JSON string. -/
def parseExprFromString (s : String) : Except String Expr := do
  let j ← Json.parse s
  parseExpr j

end Abstractfeld.Bridge
