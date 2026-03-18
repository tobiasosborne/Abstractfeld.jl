"""
    Canonical forms and structural hashing.

The structural hash of an expression is the SHA-256 of its canonical S-expression.
This gives O(1) exact-match lookup in the knowledge base.
"""

using SHA

"""
    structural_hash(e::Expr) → String

SHA-256 hex digest of the canonical S-expression. Deterministic.
"""
function structural_hash(e::Expr)
    bytes2hex(sha256(to_sexpr(e)))
end
