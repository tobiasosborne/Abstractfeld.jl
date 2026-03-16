# Abstractfeld.jl — Product Requirements Document

**Version:** 0.1 (Foundation)
**Date:** 2026-03-16
**Author:** Tobias Osborne + Claude

---

## 1. The Problem

Mathematical knowledge is trapped in three silos:

1. **Proprietary CAS systems** (Mathematica, Maple) — decades of hand-crafted rules behind paywalls, unverifiable, non-composable.
2. **Formal proof libraries** (Mathlib, Isabelle/AFP) — verified but slow to produce, disconnected from computation, practically inaccessible to working scientists.
3. **Scattered tables and folklore** (Gradshteyn-Ryzhik, DLMF, domain-specific papers) — unstructured, unverified, not machine-queryable.

No system exists that **unifies computation, verification, and knowledge accumulation** into a single open architecture. Worse, every existing CAS is built on the paradigm that Sutton's bitter lesson warns against: hand-crafted human expertise encoded as rules, which doesn't scale.

## 2. The Vision

**Abstractfeld is a verification-driven mathematical knowledge engine.** It treats formal verification (Lean4/Mathlib) as a reward signal, symbolic computation (Julia) as a fast candidate generator, and accumulated verified results as training data for the next generation of search.

The architecture inverts the traditional CAS:

```
Traditional CAS:    Human writes rules → CAS applies rules → (maybe) check
Abstractfeld:       Verifier defines truth → Search generates candidates → Knowledge accumulates
```

This is the "generator + discriminator" pattern applied to mathematics. The only irreducible human contribution is the verification kernel. Everything else — rewrite rules, canonicalization strategies, simplification heuristics — is learnable, replaceable, and should be treated as such.

### 2.1 Guiding Principles

1. **The verifier is the product.** Everything else is scaffolding that can be rebuilt. Invest disproportionately in the Lean4 kernel.

2. **Knowledge compounds.** Every verified result is stored permanently with its proof. The system gets strictly better over time. Yesterday's output is tomorrow's input.

3. **Bitter lesson compliance.** Prefer general methods (search, learning, scale) over specific methods (hand-crafted rules). When you must hand-craft, treat it as a seed heuristic, not the endgame.

4. **One IR to rule them all.** A single expression representation flows through Julia, Lean, LaTeX, and any future backend. The IR is the stable API contract.

5. **Open and composable.** No paywalls, no proprietary formats, no vendor lock-in. Every component is replaceable. The knowledge base is the moat, not the code.

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VERIFICATION KERNEL                       │
│  Lean4 + Mathlib: the ground truth oracle                   │
│  Input: (claim : Expr, proof : Tactic*) → {✓, ✗}           │
│  Axiom-free: all results backed by Mathlib foundations       │
│  The ONLY component that must be hand-crafted and trusted   │
└─────────────────────────┬───────────────────────────────────┘
                          │ reward signal (typechecks / doesn't)
┌─────────────────────────▼───────────────────────────────────┐
│                    SEARCH / GENERATION                       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ Julia engine  │  │ LLM prover   │  │ Retrieval-guided  │  │
│  │ (fast rewrites│  │ (tactic gen, │  │ (lookup similar   │  │
│  │  numeric filt)│  │  term search)│  │  verified results)│  │
│  └──────────────┘  └──────────────┘  └───────────────────┘  │
│                                                              │
│  Multiple generators compete. Only verified results survive. │
└─────────────────────────┬───────────────────────────────────┘
                          │ verified (claim, proof) pairs
┌─────────────────────────▼───────────────────────────────────┐
│                      UNIFIED IR                              │
│  S-expression AST: the universal mathematical language       │
│  Bidirectional: Julia ↔ Lean ↔ LaTeX ↔ Mathematica ↔ SymPy │
│  Canonical forms, structural hashing, fingerprinting         │
│  The stable foundation that survives all other changes       │
└─────────────────────────┬───────────────────────────────────┘
                          │ normalized expressions + metadata
┌─────────────────────────▼───────────────────────────────────┐
│                   KNOWLEDGE BASE                             │
│  Every verified result stored with:                          │
│    - canonical S-expression                                  │
│    - structural hash (O(1) lookup)                           │
│    - numerical fingerprint (fuzzy matching)                  │
│    - Lean proof artifact                                     │
│    - provenance chain                                        │
│    - verification level (L0–L4)                              │
│  Grows monotonically. Training data for learned generators.  │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Component Interactions

```
User query: "Is R_{abcd} + R_{abdc} = 0?"
  │
  ├─→ Knowledge Base: structural hash lookup → HIT → return with L4 proof
  │
  ├─→ (miss) Julia engine: simplify symbolically → candidate "yes, = 0"
  │         │
  │         └─→ Verification kernel: replay proof in Lean → ✓ → store in KB
  │
  ├─→ (miss) LLM prover: generate tactic sequence from similar proofs
  │         │
  │         └─→ Verification kernel: typecheck → ✓ → store in KB
  │
  └─→ (all miss) Numerical check: evaluate at random points → L2 evidence
              │
              └─→ Queue for formal verification (background search)
```

### 3.2 The Verification Lattice

| Level | Name | Method | Soundness | Cost |
|-------|------|--------|-----------|------|
| L0 | Unverified | None | None | Free |
| L1 | Literature | Citation | Social trust | Human time |
| L2 | Numerical | Evaluation at test points | Probabilistic | Milliseconds |
| L3 | CAS-checked | Independent CAS agrees | Oracle trust | Seconds |
| L4 | Formally verified | Lean4 proof typechecks | Mathematical certainty | Minutes–hours |

Results enter at any level and are **monotonically elevated** as resources permit. L2 is the cheap inner loop for filtering candidates before expensive L4 verification.

## 4. The Unified IR

### 4.1 Design Requirements

The IR must represent:
- **Tensor algebra**: indexed objects, contraction, symmetry, covariant derivatives
- **Integrals**: definite/indefinite, integration variables, bounds, conditions
- **General symbolic expressions**: polynomials, special functions, rational functions
- **Proof-relevant metadata**: rewrite steps, axiom applications, substitutions

All in a single grammar.

### 4.2 The S-Expression Core

```
Expr :=
  | Lit(val: Rational)                    -- exact rational coefficient
  | Sym(name: String)                     -- named symbol (variable, constant, tensor)
  | Idx(name: String, pos: Up | Down)     -- tensor index with position
  | App(op: String, args: List Expr)      -- function/operator application
  | Bind(binder: String,                  -- binding form (integral, sum, derivative)
         var: Expr,                        --   bound variable
         body: Expr,                       --   body expression
         metadata: List Expr)              --   bounds, conditions, etc.
  | Ann(expr: Expr, ann: Annotation)      -- annotated expression (types, symmetry, etc.)
```

**Serialization**: canonical S-expressions (deterministic string form for hashing).

```
# Tensor: R_{abcd}
(app "tensor" (sym "R") (idx "a" down) (idx "b" down) (idx "c" down) (idx "d" down))

# Integral: ∫₀^∞ e^{-px} dx
(bind "int" (sym "x") (app "exp" (app "neg" (app "mul" (sym "p") (sym "x"))))
  (lit 0) (sym "inf"))

# Rewrite step: e₁ →[rule] e₂
(app "rewrite" (sym "antisym_swap") expr_before expr_after)
```

### 4.3 Lean4 Mirroring

The IR has a direct Lean4 inductive type. Expressions in Julia serialize to JSON/S-expr, deserialize in Lean. The Lean side defines `eval : Expr → M` (interpretation into Mathlib structures), and proofs establish that rewrite rules preserve `eval`.

### 4.4 Backends

Each backend is a `render : Expr → String` function:

| Backend | Output | Purpose |
|---------|--------|---------|
| `render_julia` | Julia source | Computation |
| `render_lean` | Lean4 source | Verification |
| `render_latex` | LaTeX | Display |
| `render_mathematica` | Mathematica | CAS cross-check (L3) |
| `render_sympy` | SymPy/Python | CAS cross-check (L3) |
| `render_sexpr` | S-expression | Canonical form, hashing |

## 5. Knowledge Domains

### 5.1 Phase 1: Tensor Algebra (from MicroTensor + TensorGR.jl)

**Seed knowledge:**
- 7 equational axioms (to be eliminated via Mathlib)
- TensorGR.jl's rewrite rules as heuristic generators
- Bianchi identities, Riemann symmetries, metric contractions

**Verification target:**
- Lean4 proofs that tensor identities hold in `ℚ`-modules with `MultilinearMap` / `AlternatingMap`
- Eliminate all `axiom` declarations from MicroTensor

**Scaling path:**
- LLM generates candidate tensor identities by combinatorial search over index permutations
- Julia engine simplifies candidates to normal form (fast filter)
- Lean kernel verifies surviving candidates
- Verified identities enter knowledge base

### 5.2 Phase 2: Integration (from Integralis)

**Seed knowledge:**
- ~27k RUBI integrals (L2 verified)
- ~7k Gradshteyn-Ryzhik integrals (L1–L2)
- Equivalence checking pipeline (structural + numerical + algebraic)

**Verification target:**
- Lean4 proofs that `∫ f = F` (via Mathlib's `IntervalIntegral`, `HasDerivAt`)
- Start with polynomial/rational integrals where Mathlib coverage is strong

**Scaling path:**
- LLM proposes antiderivatives; numerical differentiation pre-filters; Lean verifies
- Integralis corpus is training data for the LLM proposer
- Each verified integral makes the next one easier (retrieval-augmented generation)

### 5.3 Phase 3: General Symbolic Algebra

**Target domains** (ordered by Mathlib readiness):
- Polynomial ring identities
- Matrix algebra / linear algebra identities
- Group theory computations
- Special function identities (hypergeometric, Bessel, etc.)
- ODE/PDE solution verification

### 5.4 Phase ∞: The Flywheel

At sufficient scale, the system becomes self-improving:

```
More verified results
  → better retrieval for LLM prover
    → higher proof success rate
      → more verified results (loop)
```

This is the endgame: a mathematical knowledge base that grows faster the larger it gets, because each new result makes finding the next one easier.

## 6. Relationship to Existing Projects

### 6.1 Tributaries

| Project | What flows into Abstractfeld | Status |
|---------|------------------------------|--------|
| **MicroTensor** | Verification kernel design, Julia↔Lean bridge pattern, axiom set | MVP complete |
| **TensorGR.jl** | Tensor algebra heuristics, canonicalization, 12k LOC of domain rules | Production |
| **Integralis** | Knowledge base schema, verification lattice, 50k+ integral corpus | M0 complete, M1 partial |

### 6.2 What Abstractfeld replaces

- MicroTensor's ad-hoc IR → unified S-expression IR
- MicroTensor's axioms → Mathlib-backed theorems
- TensorGR.jl's simplifier → one of many generators behind the verification kernel
- Integralis's DuckDB schema → generalized knowledge base (not integral-specific)
- All three projects' separate ASTs → one AST

### 6.3 What each project becomes

- **MicroTensor** → archived as "proof of concept" for the Julia↔Lean bridge
- **TensorGR.jl** → continues as the premier tensor CAS; Abstractfeld consumes its outputs as seed heuristics
- **Integralis** → becomes the integral-domain plugin for Abstractfeld's knowledge base

## 7. Tributary Map: The Landscape Flowing Into Abstractfeld

Abstractfeld doesn't exist in a vacuum. It harvests knowledge, patterns, and code from four ecosystems: (A) our own projects, (B) the Mathematica physics empire, (C) standalone CAS and knowledge databases, and (D) the Julia and Lean ecosystems. This section maps the top tributaries and how each flows in.

### 7.1 The Top 10 Mathematica Physics Packages

These are the crown jewels of the proprietary ecosystem — decades of domain expertise locked behind Wolfram. Ordered by strategic value for Abstractfeld.

#### 1. FeynRules (~2900 citations, most-cited HEP package)

**What**: Derives Feynman rules from a Lagrangian. Input: a model file specifying fields, symmetries, interactions. Output: vertices, propagators, coupling constants — the building blocks of perturbative QFT.

**Why it matters**: This is the *compiler frontend* of particle physics. Every BSM (beyond Standard Model) paper that computes cross-sections starts here. The Lagrangian → Feynman rules derivation is a purely algebraic operation on symbolic expressions — exactly Abstractfeld's domain.

**How it flows in**: The Lagrangian → vertex derivation is a sequence of algebraic rewrites (functional derivatives, index contractions, symmetry factor computation). Each step is verifiable. An Abstractfeld-native FeynRules would produce vertex rules *with proofs* that they follow from the Lagrangian. **Phase 3+ target.** No Julia equivalent exists.

#### 2. FeynCalc (~2000 citations)

**What**: Full symbolic QFT workbench — Dirac gamma matrix algebra, color algebra (SU(N) traces), loop integral reduction (Passarino-Veltman), tensor decomposition. The Swiss army knife of perturbative calculations.

**Why it matters**: The core operations (gamma traces, color traces, tensor reduction) are finite algebraic identities. They're provable. Currently they're just *trusted code*.

**How it flows in**: Extract the algebraic identities (trace formulas, Fierz identities, Passarino-Veltman reduction formulas) as knowledge base entries. These are exact, finite, and formalizable. The gamma algebra `{γ^μ, γ^ν} = 2g^{μν}` is a Clifford algebra — Mathlib already has `CliffordAlgebra`. **Phase 3 target.** Partial Julia coverage: FeAmGen.jl wraps QGRAF for diagram generation but has no symbolic amplitude manipulation.

#### 3. xAct (~1000 citations)

**What**: Abstract tensor algebra — canonicalization via computational group theory (Butler-Portugal algorithm), covariant derivatives, Riemann tensor identities.

**How it flows in**: **Already flowing.** TensorGR.jl is a full Julia port. MicroTensor verifies a subset in Lean. Abstractfeld inherits both. The next step is verifying TensorGR's canonicalization results, not reimplementing the canonicalizer.

#### 4. FeynArts (~1000 citations)

**What**: Generates Feynman diagrams as topologies + field assignments. Works with FeynCalc and FormCalc for amplitude computation.

**How it flows in**: Diagram generation is a combinatorial graph problem — enumerate topologies, assign fields consistent with vertices. The generation itself doesn't need verification, but the *amplitude* derived from each diagram does. Partial Julia coverage: FeAmGen.jl wraps QGRAF.

#### 5. FIRE / LiteRed / Kira (IBP reduction)

**What**: Integration-By-Parts (IBP) reduction — reduces any Feynman loop integral to a basis of "master integrals" using algebraic identities derived from IBP relations.

**Why it matters**: IBP reduction is the computational bottleneck of modern perturbative QFT. FIRE alone processes systems with millions of equations. The reduction *identities* are algebraic — each one says "this integral equals this linear combination of simpler integrals."

**How it flows in**: The IBP identities themselves are provable algebraic relations. Store them in the KB with proofs. The master integral *values* are the hard part (often involving multiple polylogarithms, elliptic integrals) — these flow into the Integralis side. FIRE's C++ core could be called from Julia as a generator. **Phase 4+ target.**

#### 6. Package-X (~414 citations)

**What**: Analytic evaluation of one-loop integrals in dimensional regularization. Produces closed-form results in terms of logarithms and dilogarithms.

**How it flows in**: Each one-loop integral evaluation is a mathematical identity: "this Feynman integral equals this combination of special functions." These are exactly Integralis entries with physics provenance. The reduction formulas (Passarino-Veltman) are algebraic identities. **Phase 3 target.** No Julia equivalent for the symbolic engine.

#### 7. SARAH (~850 citations)

**What**: SUSY model builder — takes a superpotential and gauge group, derives the full Lagrangian, mass matrices, RGEs, vertices.

**How it flows in**: SARAH's output is algebraic: mass matrices, beta functions, vertex factors. These are derivable from the Lagrangian by differentiation and algebraic manipulation — all verifiable. Lower priority: very domain-specific. No Julia equivalent.

#### 8. FormCalc (extends FeynArts)

**What**: Evaluates Feynman amplitudes numerically by generating optimized Fortran/C code from symbolic expressions.

**How it flows in**: The symbolic → numeric compilation step could use Abstractfeld's IR as an intermediate representation. Lower priority: numerical code generation is a solved problem. Julia's own code generation is already excellent.

#### 9. HPL / Harmonic Polylogarithms

**What**: Implements harmonic polylogarithms (HPLs) — the special functions that appear in multi-loop Feynman integrals. Includes algebraic relations (shuffle algebra, stuffle algebra).

**How it flows in**: The algebraic identities among HPLs (shuffle product, stuffle product, duality relations) are finite and provable. They're natural KB entries. The HPLs themselves extend Integralis into the multi-loop domain. **Phase 3 target.** No Julia equivalent.

#### 10. HolonomicFunctions / Sigma / EvaluateMultiSums

**What**: Proves and discovers identities for hypergeometric sums and integrals using holonomic systems (Zeilberger's algorithm, creative telescoping).

**Why it matters**: This is the *algorithm that discovers identities* — exactly the kind of generator Abstractfeld needs. Given a sum or integral, it algorithmically finds a recurrence relation, then proves it satisfies a closed form.

**How it flows in**: Implement Zeilberger-style algorithms in Julia as a *generator*. Each discovered identity is verified by Lean, stored in KB. This is the most "bitter lesson compliant" of the Mathematica packages — it's already search-based, not hand-crafted. **Phase 4 target.** Partial Julia coverage: HypergeometricFunctions.jl evaluates but doesn't prove identities.

### 7.2 Standalone CAS and Knowledge Databases

#### FORM (Vermaseren)

**What**: Ultra-high-performance symbolic manipulator for particle physics. Handles expressions with *billions* of terms. Used for 4-loop and 5-loop QCD calculations.

**Architecture insight**: FORM's secret is its *flat term stream* — expressions are never stored as trees. They're sequential word-encoded terms processed one at a time, sorted by merge sort, and spilled to disk. This is why it handles expressions that would crash any tree-based CAS.

**How it flows in**: Not as code (FORM is C, specialized). As an *architectural lesson*: for large-scale symbolic computation, flat-stream processing with disk spilling beats tree manipulation. Abstractfeld's IR should support both tree (for proof generation) and flat-stream (for large-scale computation) representations. FORM's color algebra module (`color.h`) contains SU(N) trace identities that are directly extractable as KB entries.

#### Cadabra

**What**: Field theory symbolic computation. Unique contribution: **Young projector** approach to multi-term symmetries (Bianchi identity, Schouten identity) — goes beyond xAct's pairwise symmetries.

**How it flows in**: Cadabra's Young projector machinery is the path beyond MicroTensor's current `Antisym(slot1, slot2)` representation. For the Bianchi identity `R_{abcd} + R_{acdb} + R_{adbc} = 0`, you need *cyclic* symmetry, not just pairwise. Cadabra's approach should inform the IR extension. Its "scratchpad" philosophy (no automatic simplification, user controls each step) aligns with trace-emitting CAS design.

#### Redberry

**What**: Java-based tensor CAS. Unique insight: represents tensor expressions as *graphs* and reduces tensor comparison to **graph isomorphism** (via nauty/Traces).

**How it flows in**: Graph-based tensor representation is a fundamentally different approach from tree-based canonicalization. For certain problems (especially those with many dummy indices), graph isomorphism may be more natural. Worth investigating as an alternative generator.

#### Maxima / REDUCE

**What**: The original open-source CAS systems (1960s–70s, Lisp-based). Maxima has ~1400 integration rules; REDUCE has efficient polynomial algorithms.

**How it flows in**: These are *harvestable knowledge*. The integration rules in Maxima are essentially Integralis entries waiting to be extracted, canonicalized, and verified. REDUCE's algorithms for polynomial GCD, factorization, and simplification are well-documented and could seed Julia generators.

### 7.3 Knowledge Databases

| Database | Domain | Size | API | Extraction Path |
|----------|--------|------|-----|-----------------|
| **DLMF** (NIST) | Special functions | ~4000 identities | Semantic LaTeX/XML | Integralis M1 pipeline (already designed) |
| **LMFDB** | L-functions, modular forms, elliptic curves, number fields | 5M+ objects | REST API (JSON/YAML) | Direct API queries → KB entries |
| **OEIS** | Integer sequences | 380k+ sequences | HTTP API + SQLite | Already done: **Sequencelib** has formalized 25k+ sequences in Lean4 with 1.6M proved theorems |
| **Stacks Project** | Algebraic geometry | 7700+ results | JSON API with dependency graphs | Theorem statements + dependencies extractable |
| **Wolfram Functions** | All special functions | 300k+ formulas | Web scraping only | Integralis Wolfram pipeline (partial) |
| **GR tables** (Gradshteyn-Ryzhik) | Integrals | ~12k entries | PDF (OCR'd) | Integralis M1 pipeline (7k ingested) |
| **Invar/xTras catalog** | Curvature invariants | ~200 invariants | Mathematica files | Direct extraction to KB |

**Critical discovery**: **Sequencelib** (github.com/bhavik-knight/sequencelib) has already formalized >25,000 OEIS sequences in Lean 4 with >1.6 million proved theorems. This is *proof that verified knowledge extraction at scale works*. The pattern: programmatic generation of Lean files → batch verification → accumulate. Exactly Abstractfeld's architecture.

### 7.4 The Julia Ecosystem

#### TermInterface.jl — The Universal Protocol

TermInterface.jl defines a minimal protocol (`iscall()`, `operation()`, `arguments()`, `maketerm()`) that any Julia type can implement. Any type satisfying this interface can be manipulated by SymbolicUtils.jl, Metatheory.jl, and other JuliaSymbolics tools.

**Decision**: Abstractfeld's IR types should implement TermInterface.jl. This gives free interop with the entire JuliaSymbolics stack without coupling to their specific representations.

#### Metatheory.jl — E-Graphs as the Rewriting Engine

**Key insight**: E-graph equality saturation is strictly superior to sequential rewriting for proof-relevant computation:
- **Non-destructive**: all equivalent forms coexist (no lost intermediate states)
- **Unordered**: no "smart constructor swallows trace steps" problem (MicroTensor's hardest bug)
- **Optimal extraction**: select the form with the shortest proof, not just the simplest expression
- **Bidirectional rules**: `a + b = b + a` doesn't loop

Metatheory.jl v3 achieves up to 226x speedup over v2, competitive with egg (Rust). Pure Julia.

**Gap**: Metatheory.jl does not currently emit proof traces. Adding proof-trace extraction to the e-graph saturation loop is the key integration point for Abstractfeld.

**Decision**: Investigate e-graphs as Abstractfeld's simplification engine. The extracted equivalence proof → Lean verification pipeline would be the core loop.

#### Oscar.jl — The Heavyweight

Oscar.jl orchestrates GAP, Singular, Polymake, and FLINT from Julia. Comprehensive coverage of algebra, algebraic geometry, number theory, polyhedral geometry. Version 1.7.0, funded by German DFG.

**Relationship**: Oscar is a *complementary* system, not a competitor. Abstractfeld can call Oscar for heavy algebraic computation (Gröbner bases, group computations) and verify the results. Oscar has no verification story — that's Abstractfeld's unique value.

#### SciLean (Lean 4) — The Mirror Image

SciLean puts scientific computing *inside* Lean 4: verified automatic differentiation, symbolic computation, interactive CAS. Early stage (397 stars). Philosophically aligned but approaches from the opposite direction: everything in Lean vs. computation in Julia.

**Relationship**: Watch and learn. If SciLean succeeds, it validates the vision. If it struggles with performance (likely — Lean's runtime is not Julia's JIT), it validates the two-language architecture.

### 7.5 The Lean/Mathlib Ecosystem

#### Mathlib Coverage (as of early 2026, ~250k theorems)

| Domain | Coverage | Abstractfeld Relevance |
|--------|----------|----------------------|
| Linear algebra, modules, tensor products | **Strong** | Core: axiom elimination for MicroTensor |
| Multilinear maps, alternating maps | **Strong** | `AlternatingMap.map_swap` exists — proves `antisym_swap` |
| Exterior algebra, Clifford algebra | **Strong** | Gamma matrix algebra (FeynCalc domain) |
| Real/complex analysis, derivatives | **Strong** | FTC for integral verification |
| Measure theory, Bochner/Lebesgue integral | **Strong** | Definite integral verification |
| Gamma/Beta functions | **Present** | Integralis L4 for gamma-class integrals |
| Bessel, hypergeometric, Airy | **Absent** | Blocks L4 for most special-function integrals |
| Differential geometry (connections, curvature) | **Absent** | Blocks geometric interpretation of tensor identities |
| Lie group/algebra representations | **Absent** | Blocks representation-theoretic physics |
| Special functions beyond Gamma | **Absent** | Major gap for Integralis L4 elevation |

**Key finding**: All Mathlib lemmas needed for MicroTensor's axiom elimination are confirmed present. The semantic interpretation strategy (`Module ℚ M` with `AlternatingMap.map_swap`) is feasible *today*.

#### PhysLean / HepLean

Formalizes physics directly in Lean 4. Published formalization of physics index notation (arXiv:2411.07667). Covers: Maxwell's equations, quantum harmonic oscillator, Wick's theorem, Lorentz tensors. 2,536 commits, 517 stars.

**Relationship**: Complementary. PhysLean formalizes the *physics*; Abstractfeld verifies the *computation*. Potential for shared infrastructure (tensor index notation, Lorentz algebra).

#### LLM Proof Automation (State of the Art, March 2026)

| Tool | Approach | Success Rate | Open Source |
|------|----------|-------------|-------------|
| **Lean Copilot** (ReProver) | Retrieval-augmented tactic generation | 74% of proof steps | Yes |
| **LeanHammer** | Premise selection + ATP (Duper) | 37% of Mathlib theorems | Yes |
| **DeepSeek-Prover-V2** | 671B parameter LLM | 89% MiniF2F | Yes (weights) |
| **Goedel-Prover-V2** | 32B parameter LLM | 86/658 PutnamBench | Yes |
| **Seed-Prover 1.5** | Multi-stage RL | 5/6 IMO 2025 | No |
| **AlphaProof** | AlphaZero-inspired RL | IMO silver | No |

**For Abstractfeld's M3 (Search Loop)**: Lean Copilot is the practical starting point for automated proof generation. LeanHammer for harder goals. The LLM provers validate the bitter-lesson thesis: search + scale finds proofs.

### 7.6 Tributary Flow Summary

```
MATHEMATICA EMPIRE                    STANDALONE CAS           KNOWLEDGE DATABASES
─────────────────                    ──────────────           ───────────────────
FeynRules (Lagrangian→vertices)      FORM (architecture)      DLMF (special fns)
FeynCalc (γ-traces, color, loops)    Cadabra (Young proj.)    LMFDB (number theory)
xAct ──→ TensorGR.jl ──┐            Redberry (graph repr.)   OEIS → Sequencelib ─┐
FIRE/LiteRed (IBP)      │           Maxima (integ. rules)    Stacks Project       │
Package-X (1-loop)       │           REDUCE (poly algs)       GR tables ──→────────┤
SARAH (SUSY models)      │                                    Invar catalog        │
HPL (polylogarithms)     │           ┌─── E-graphs ───┐                            │
HolonomicFunctions       │           │  Metatheory.jl  │      ┌── Lean/Mathlib ──┐ │
  (Zeilberger)           │           │  (rewriting     │      │  250k theorems   │ │
                         │           │   engine)       │      │  AlternatingMap  │ │
                         │           └────────┬────────┘      │  FTC, integrals  │ │
OUR PROJECTS             │                    │               │  CliffordAlgebra │ │
────────────             │                    │               │  PhysLean        │ │
MicroTensor ─────────────┤                    │               │  LLM provers     │ │
Integralis ──────────────┤                    │               └────────┬─────────┘ │
TensorGR.jl ─────────────┤                    │                        │            │
                         │                    │                        │            │
                         ▼                    ▼                        ▼            ▼
                    ┌─────────────────────────────────────────────────────────────────┐
                    │                                                                 │
                    │                    A B S T R A C T F E L D                      │
                    │                                                                 │
                    │   Unified IR ←→ Verification Kernel ←→ Knowledge Base           │
                    │       ↑                   ↑                   ↑                 │
                    │       │          Search / Generation          │                 │
                    │       │         (Julia + LLM + E-graphs)      │                 │
                    │       └───────────────────┴───────────────────┘                 │
                    │                                                                 │
                    └─────────────────────────────────────────────────────────────────┘
```

### 7.7 Porting Priority Matrix

Which tributaries to tap first, based on (feasibility × impact × Mathlib readiness):

| Priority | Tributary | Domain Added | Mathlib Ready? | Julia Exists? | Est. Effort |
|----------|-----------|-------------|----------------|---------------|-------------|
| **P0** | MicroTensor + Integralis | Tensors + Integrals | Yes (modules, FTC) | Yes (ours) | Weeks |
| **P1** | TensorGR.jl rules | GR identities (100+) | Yes (alternating maps) | Yes (ours) | Weeks |
| **P1** | Sequencelib pattern | Proof-at-scale methodology | N/A | Learn from | Days |
| **P2** | Maxima integration rules | ~1400 integral identities | Partial (FTC) | Extract | Months |
| **P2** | DLMF | ~4000 special fn identities | Partial (Gamma only) | Integralis pipeline | Months |
| **P3** | FeynCalc traces | γ-matrix algebra | Yes (CliffordAlgebra) | No | Months |
| **P3** | FORM color.h | SU(N) identities | Partial | No | Months |
| **P3** | HPL identities | Polylogarithm algebra | No | No | Months |
| **P4** | FeynRules | Lagrangian → vertices | No (needs Lie reps) | No | Quarters |
| **P4** | IBP relations | Loop integral reduction | No | No | Quarters |
| **P5** | HolonomicFunctions | Algorithmic identity discovery | No (hypergeometric) | No | Quarters |
| **P5** | LMFDB/Stacks | Number theory/alg. geom. | Partial | API exists | Quarters |

### 7.8 Key Architectural Decisions Informed by This Landscape

1. **Implement TermInterface.jl on Abstractfeld's IR.** Free interop with the entire JuliaSymbolics stack (Metatheory.jl, SymbolicUtils.jl) without coupling to their representations.

2. **Use Metatheory.jl's e-graphs as the rewriting engine**, with proof-trace extraction added. This solves MicroTensor's "smart constructor swallows trace steps" problem at the architectural level. Equality saturation finds all equivalent forms; extraction picks the one with the shortest proof.

3. **Support both tree and flat-stream IR representations.** Tree for proof generation (small expressions); flat-stream à la FORM for large-scale computation (millions of terms). The verification kernel only sees tree form.

4. **Extend the symmetry representation beyond pairwise.** MicroTensor's `Antisym(slot1, slot2)` → Young tableaux (Cadabra-style) for multi-term identities (Bianchi, Schouten). This is needed before P3 (FeynCalc/Cadabra domains).

5. **Call Oscar.jl for heavy algebra.** Don't reimplement Gröbner bases or group theory. Use Oscar as a generator; verify results with Lean.

6. **Learn from Sequencelib's methodology.** Programmatic Lean file generation → batch `lake build` → accumulate. This is the proven path for verified knowledge at scale. Adapt for identities instead of sequences.

## 8. Technical Decisions

### 8.1 Language Choices

| Layer | Language | Rationale |
|-------|----------|-----------|
| IR, generation, orchestration | **Julia** | Homoiconic (Expr ≈ S-expr natively), fast JIT for numerical filtering, mature metaprogramming, scientific computing ecosystem |
| Verification kernel | **Lean4** | Mathlib is the largest formalized math library; dependent types for proof terms; `lake` build system |
| LLM integration | **Julia + HTTP** | Call LLM APIs from Julia; parse responses into IR; submit to Lean |
| Knowledge base | **DuckDB** (embedded) | Single-file, distributable, columnar (fast analytical queries), SQL interface |
| Interchange | **S-expressions over JSON** | Deterministic serialization for hashing; human-readable; trivially parseable in any language |

### 8.2 Why Not Pure Lean?

Lean4 is Turing-complete and could in principle do everything. But:
- **Speed**: Julia's JIT is 10–100x faster for numerical pre-filtering
- **Ecosystem**: Julia has ArbNumerics, DuckDB, HTTP clients, plotting — Lean doesn't
- **Iteration speed**: Julia's REPL + hot-reload vs. Lean's `lake build` cycle
- **Interop**: Julia talks to Python (SymPy), Mathematica (MathLink), databases trivially

The bitter lesson says use *general* computation. Julia is the general computation layer. Lean is the *specific* verification layer — the one place where hand-crafted precision is the point.

### 8.3 Why Not Pure Julia?

Julia can do symbolic computation (Symbolics.jl, SymbolicUtils.jl). But:
- **No formal guarantees**: Symbolics.jl is not verified. Bugs in simplification are silent.
- **No proof objects**: Julia computation produces answers, not evidence. The gap between "the CAS says X" and "X is true" is the entire point of this project.
- **Mathlib**: 150k+ theorems, actively maintained, growing. Rebuilding this in Julia is insane.

## 9. Milestones

### M0: Foundation (Weeks 1–4)

**Goal**: Unified IR with bidirectional Julia↔Lean serialization.

Deliverables:
- [ ] `src/ir/` — Julia IR types (Lit, Sym, Idx, App, Bind, Ann)
- [ ] `src/ir/sexpr.jl` — S-expression serialization/parsing
- [ ] `src/ir/canonical.jl` — canonical form, structural hashing
- [ ] `src/ir/render/` — LaTeX, Lean4, Mathematica, SymPy backends
- [ ] `lean/Abstractfeld/IR.lean` — Lean4 inductive types mirroring Julia IR
- [ ] `lean/Abstractfeld/Parse.lean` — JSON/S-expr → Lean IR deserialization
- [ ] Round-trip test: Julia expr → S-expr → Lean → typecheck → S-expr → Julia expr
- [ ] Port MicroTensor's tensor expressions into the new IR
- [ ] Port Integralis's `IntExpr` into the new IR

**Success criterion**: `lake build` passes; Julia round-trip tests pass; both tensor and integral expressions representable.

### M1: Verification Kernel (Weeks 5–10)

**Goal**: Lean4 verification of tensor identities without axioms.

Deliverables:
- [ ] `lean/Abstractfeld/Interpret.lean` — `eval : Expr → Module M` interpretation
- [ ] `lean/Abstractfeld/Tensor.lean` — tensor identities as Mathlib theorems (not axioms)
- [ ] `lean/Abstractfeld/Integral.lean` — stub for integral verification (polynomial only)
- [ ] Proof: `R_{abcd} + R_{abdc} = 0` as a Mathlib theorem (no axioms, no sorry)
- [ ] Proof: at least 3 additional tensor identities from TensorGR.jl's rule set
- [ ] Julia orchestrator: `verify(claim::Expr) → VerificationResult`

**Success criterion**: `#check @[no_axiom]` on all proofs; Julia can submit claims and receive verified/rejected responses.

### M2: Knowledge Base (Weeks 8–14)

**Goal**: Persistent store of verified mathematical results.

Deliverables:
- [ ] `src/kb/` — DuckDB schema generalized from Integralis
- [ ] `src/kb/store.jl` — insert verified results with proof artifacts
- [ ] `src/kb/query.jl` — structural hash lookup + fingerprint fuzzy matching
- [ ] `src/kb/provenance.jl` — append-only provenance tracking
- [ ] Ingest MicroTensor's verified tensor identities
- [ ] Ingest Integralis's L2+ integral corpus (with provenance)
- [ ] Unified query API: `lookup(expr) → List{(result, proof, level)}`

**Success criterion**: Single query interface returns both tensor identities and integrals; all results carry verification level and provenance.

### M3: Search Loop (Weeks 12–20)

**Goal**: LLM-guided proof generation with verification in the loop.

Deliverables:
- [ ] `src/search/` — candidate generation framework
- [ ] `src/search/julia_engine.jl` — TensorGR-style rewriting as a generator
- [ ] `src/search/llm_prover.jl` — LLM tactic generation (Claude API)
- [ ] `src/search/retrieval.jl` — retrieve similar verified results to seed LLM context
- [ ] `src/search/numerical_filter.jl` — cheap L2 pre-filter before expensive L4 verification
- [ ] End-to-end: user poses identity → search generates proof → Lean verifies → KB stores
- [ ] Benchmark: success rate on held-out tensor identities from TensorGR.jl

**Success criterion**: LLM prover finds proofs for identities not in the seed set; success rate > 50% on benchmark.

### M4: Flywheel (Weeks 18–30)

**Goal**: Demonstrate self-improvement — larger KB → higher proof success rate.

Deliverables:
- [ ] Batch verification pipeline: submit 1000+ candidate identities overnight
- [ ] Measure proof success rate as KB size grows (learning curve)
- [ ] Retrieval-augmented generation: similar proofs in context improves LLM success
- [ ] Community contribution interface: submit claims for verification
- [ ] Dashboard: KB size, verification rates, domain coverage

**Success criterion**: Measurable improvement in proof success rate as KB grows from 100 → 1000 → 10000 verified results.

## 10. What Success Looks Like

### In 6 months
A working system where you can type a tensor identity or integral, and get back either a cached L4 proof or a freshly-generated-and-verified one. The knowledge base has ~1000 formally verified results spanning tensors and integrals.

### In 2 years
The knowledge base has 100k+ verified results. The LLM prover's success rate has measurably improved from KB growth. Researchers use Abstractfeld to verify results in papers. The verification lattice means fast approximate answers (L2) are always available, with formal proofs (L4) accumulating in the background.

### In 5 years
Abstractfeld is to mathematical knowledge what Wikipedia is to encyclopedic knowledge: an open, growing, community-maintained corpus — but with machine-checked proofs instead of editorial review. The bitter lesson has played out: the hand-crafted rules that seeded the system have been superseded by learned search policies that find proofs humans wouldn't write.

## 11. Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Mathlib coverage gaps (confirmed: no Bessel/hypergeometric, no connections/curvature) | High | Phase 1–2 use strong areas (modules, alternating maps, FTC). Phase 3+ blocked on special functions — contribute upstream or work around |
| LLM proof generation too unreliable | Medium | Numerical pre-filtering (L2) reduces search space by 100x; retrieval augmentation provides good examples |
| Unified IR too complex (kitchen sink) | High | Start minimal (MicroTensor's 5 nodes); extend only when a concrete domain requires it |
| Lean build times slow the feedback loop | Medium | Cache proof artifacts; only re-verify on IR change; `native_decide` for decidable fragments |
| DuckDB scaling limits | Low | DuckDB handles millions of rows; if exceeded, migrate to Postgres (same SQL) |
| Scope creep into "build all of Mathlib" | High | Abstractfeld *uses* Mathlib, it doesn't *replace* it. Proofs import Mathlib theorems. |

## 12. Non-Goals

- **Replacing Mathlib.** Abstractfeld is a consumer of Mathlib, not a competitor. It adds a computation and retrieval layer on top.
- **Competing with Mathematica on UX.** The interface is programmatic (Julia REPL + API), not a notebook GUI. UX can come later.
- **Real-time performance.** L4 verification takes seconds-minutes. That's fine. L2 (numerical) is the fast path.
- **Supporting every mathematical domain immediately.** Phase 1 is tensors. Phase 2 is integrals. Generalize from success, not from aspiration.

## 13. The Name

**Abstractfeld** (German: "abstract field") — a field in both the algebraic sense (a mathematical structure where you can add, multiply, and divide) and the agricultural sense (a field you cultivate). The abstract field where verified mathematical knowledge grows.

The `-feld` suffix also echoes the project's German-academic heritage and pairs naturally with Julia's Germanic naming conventions. And it's not taken.

---

*"The biggest lesson that can be read from 70 years of AI research is that general methods that leverage computation are ultimately the most effective, and by a large margin."* — Rich Sutton, The Bitter Lesson (2019)

Abstractfeld is what happens when you take the bitter lesson seriously in mathematics.
