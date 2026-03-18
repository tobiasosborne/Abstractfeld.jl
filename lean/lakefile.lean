import Lake
open Lake DSL

package Abstractfeld where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

@[default_target]
lean_lib Abstractfeld where
  roots := #[`Abstractfeld]

lean_exe roundtrip where
  root := `Abstractfeld.Bridge.RoundTrip

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "master"
