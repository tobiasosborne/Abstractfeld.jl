"""
    LaTeX renderer for the IR.

Renders IR expressions as LaTeX strings for display and debugging.
"""

"""
    render_latex(e::Expr) → String

Render an expression as LaTeX.
"""
function render_latex(e::Lit)
    v = e.val
    if isone(denominator(v))
        n = numerator(v)
        return n < 0 ? "{$(n)}" : string(n)
    else
        return "\\frac{$(numerator(v))}{$(denominator(v))}"
    end
end

render_latex(e::Sym) = _latex_sym(e.name)

function _latex_sym(name::Symbol)
    s = string(name)
    # Greek letters
    greeks = Dict(
        "alpha" => "\\alpha", "beta" => "\\beta", "gamma" => "\\gamma",
        "delta" => "\\delta", "epsilon" => "\\epsilon", "zeta" => "\\zeta",
        "eta" => "\\eta", "theta" => "\\theta", "iota" => "\\iota",
        "kappa" => "\\kappa", "lambda" => "\\lambda", "mu" => "\\mu",
        "nu" => "\\nu", "xi" => "\\xi", "pi" => "\\pi",
        "rho" => "\\rho", "sigma" => "\\sigma", "tau" => "\\tau",
        "upsilon" => "\\upsilon", "phi" => "\\phi", "chi" => "\\chi",
        "psi" => "\\psi", "omega" => "\\omega",
        "Gamma" => "\\Gamma", "Delta" => "\\Delta", "Theta" => "\\Theta",
        "Lambda" => "\\Lambda", "Xi" => "\\Xi", "Pi" => "\\Pi",
        "Sigma" => "\\Sigma", "Phi" => "\\Phi", "Psi" => "\\Psi",
        "Omega" => "\\Omega",
        "inf" => "\\infty",
    )
    return get(greeks, s, s)
end

function render_latex(e::Idx)
    _latex_sym(e.name)
end

function render_latex(e::App)
    op = e.op
    args = e.args

    if op == :tensor
        return _render_tensor(args)
    elseif op == :+
        return join([render_latex(a) for a in args], " + ")
    elseif op == :- && length(args) == 1
        return "-" * _paren_if_compound(args[1])
    elseif op == :- && length(args) == 2
        return render_latex(args[1]) * " - " * _paren_if_compound(args[2])
    elseif op == :*
        return _render_mul(args)
    elseif op == :/ && length(args) == 2
        return "\\frac{" * render_latex(args[1]) * "}{" * render_latex(args[2]) * "}"
    elseif op == :^ && length(args) == 2
        return _paren_if_compound(args[1]) * "^{" * render_latex(args[2]) * "}"
    elseif op == :neg && length(args) == 1
        return "-" * _paren_if_compound(args[1])
    elseif op == :exp && length(args) == 1
        return "e^{" * render_latex(args[1]) * "}"
    elseif op == :sqrt && length(args) == 1
        return "\\sqrt{" * render_latex(args[1]) * "}"
    elseif op == :abs && length(args) == 1
        return "\\left|" * render_latex(args[1]) * "\\right|"
    else
        # Generic function application
        fname = _latex_sym(op)
        argstr = join([render_latex(a) for a in args], ", ")
        return fname * "\\left(" * argstr * "\\right)"
    end
end

function _render_tensor(args::Vector{Expr})
    isempty(args) && return ""
    name = render_latex(args[1])
    length(args) == 1 && return name

    indices = args[2:end]
    subs = String[]
    sups = String[]
    for idx_expr in indices
        if idx_expr isa Idx
            s = _latex_sym(idx_expr.name)
            if idx_expr.pos == Down
                push!(subs, s)
            else
                push!(sups, s)
            end
        end
    end

    result = name
    if !isempty(subs)
        result *= "_{" * join(subs) * "}"
    end
    if !isempty(sups)
        result *= "^{" * join(sups) * "}"
    end
    return result
end

function _render_mul(args::Vector{Expr})
    parts = String[]
    for a in args
        if a isa App && a.op in (:+, :-)
            push!(parts, "\\left(" * render_latex(a) * "\\right)")
        else
            push!(parts, render_latex(a))
        end
    end
    return join(parts, " ")
end

function _paren_if_compound(e::Expr)
    if e isa App && e.op in (:+, :-, :*)
        return "\\left(" * render_latex(e) * "\\right)"
    end
    return render_latex(e)
end

function render_latex(e::Bind)
    if e.binder == :int
        var = render_latex(e.var)
        body = render_latex(e.body)
        if length(e.metadata) >= 2
            lo = render_latex(e.metadata[1])
            hi = render_latex(e.metadata[2])
            return "\\int_{$lo}^{$hi} $body \\, d$var"
        else
            return "\\int $body \\, d$var"
        end
    elseif e.binder == :sum
        var = render_latex(e.var)
        body = render_latex(e.body)
        if length(e.metadata) >= 2
            lo = render_latex(e.metadata[1])
            hi = render_latex(e.metadata[2])
            return "\\sum_{$var=$lo}^{$hi} $body"
        else
            return "\\sum_{$var} $body"
        end
    elseif e.binder == :diff
        var = render_latex(e.var)
        body = render_latex(e.body)
        return "\\frac{d}{d$var} $body"
    else
        # Generic binder
        return string(e.binder) * "_{" * render_latex(e.var) * "} " * render_latex(e.body)
    end
end

function render_latex(e::Ann)
    # Annotations are invisible in LaTeX output
    render_latex(e.expr)
end
