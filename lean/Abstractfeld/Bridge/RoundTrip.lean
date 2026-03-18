/-
  Abstractfeld.Bridge.RoundTrip
  Reads JSON from stdin, parses to Expr, serializes back, writes to stdout.
  Used by the Julia round-trip test.
-/
import Abstractfeld.Bridge.Parse

open Abstractfeld.IR
open Abstractfeld.Bridge

def main : IO Unit := do
  let input ← IO.getStdin >>= (·.readToEnd)
  for line in input.splitOn "\n" do
    let line := line.trim
    if line.isEmpty then continue
    match parseExprFromString line with
    | .ok expr => IO.println ((exprToJson expr).compress)
    | .error msg => IO.eprintln s!"ERROR: {msg}"
