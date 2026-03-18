# Tensor algebra rewrite rules as e-graph theories.
# These rules encode algebraic identities that the saturation engine
# uses to discover equivalences between tensor expressions.

using ..EGraphRewriting: @rule, @theory, @slots

"""
    basic_algebra()

Basic algebraic identities: commutativity and associativity of +,
additive identity, negation cancellation.
"""
function basic_algebra()
    @slots a b c @theory begin
        a + b == b + a                        # commutativity of +
        (a + b) + c == a + (b + c)            # associativity of +
        a + 0 --> a                            # additive identity (right)
        0 + a --> a                            # additive identity (left)
        a + (-a) --> 0                         # negation cancellation
        (-a) + a --> 0                         # negation cancellation (symmetric)
        -(-a) --> a                            # double negation
        -(a + b) --> (-a) + (-b)               # distribute negation
    end
end

"""
    scalar_rules()

Scalar multiplication rules for tensor expressions.
"""
function scalar_rules()
    @slots a b c @theory begin
        0 * a --> 0                            # zero absorbs
        1 * a --> a                            # multiplicative identity
        a * (b + c) --> (a * b) + (a * c)      # left distributivity
    end
end

"""
    tensor_algebra()

Combined tensor algebra theory: basic algebra + scalar rules.
This is the default theory for tensor expression simplification.
"""
function tensor_algebra()
    vcat(basic_algebra(), scalar_rules())
end
