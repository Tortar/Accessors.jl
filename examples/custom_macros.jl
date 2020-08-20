# # Extending `@set` and `@lens`
# This code demonstrates how to extend the `@set` and `@lens` mechanism with custom
# lenses.
# As a demo, we want to implement `@mylens!` and `@myreset`, which work much like
# `@lens` and `@set`, but mutate objects instead of returning modified copies.

using Setfield
using Setfield: IndexLens, PropertyLens, ComposedLens

struct Lens!{L}
    pure::L
end

(l::Lens!)(o) = l.pure(o)
function Setfield.set(o, l::Lens!{<: ComposedLens}, val)
    o_inner = Setfield.inner(l.pure)(o)
    set(o_inner, Lens!(Setfield.outer(l.pure)), val)
end
function Setfield.set(o, l::Lens!{PropertyLens{prop}}, val) where {prop}
    setproperty!(o, prop, val)
    o
end
function Setfield.set(o, l::Lens!{<:IndexLens}, val) where {prop}
    o[l.pure.indices...] = val
    o
end

# Now this implements the kind of `lens` the new macros should use.
# Of course there are more variants like `Lens!(<:DynamicIndexLens)`, for which we might
# want to overload `set`, but lets ignore that. Instead we want to check, that everything works so far:

using Test
mutable struct M
    a
    b
end

o = M(1,2)
l = Lens!(@lens _.b)
set(o, l, 20)
@test o.b == 20

l = Lens!(@lens _.foo[1])
o = (foo=[1,2,3], bar=:bar)
set(o, l, 100)
@test o == (foo=[100,2,3], bar=:bar)

# Now we can implement the syntax macros

using Setfield: setmacro, lensmacro

macro myreset(ex)
    setmacro(Lens!, ex)
end

macro mylens!(ex)
    lensmacro(Lens!, ex)
end

o = M(1,2)
@myreset o.a = :hi
@myreset o.b += 98
@test o.a == :hi
@test o.b == 100

deep = [[[[1]]]]
@myreset deep[1][1][1][1] = 2
@test deep[1][1][1][1] === 2

l = @mylens! _.foo[1]
o = (foo=[1,2,3], bar=:bar)
set(o, l, 100)
@test o == (foo=[100,2,3], bar=:bar)

# Everything works, we can do arbitrary nesting and also use `+=` syntax etc.
