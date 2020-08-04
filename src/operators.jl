import Base: (^), (*), (~), (/), (|), (!)

(*)(x::Any, y::AbstractToken) = sSequence(parser(x),y)
(*)(x::AbstractToken, y::Any) = sSequence(x,parser(y))
(*)(x::AbstractToken, y::AbstractToken) = sSequence(x,y)

## todo: cuts

(|)(x, y::ParserTypes) = sEither(parser(x),y)
(|)(x::ParserTypes, y) = sEither(x,parser(y))
"""
    (|)(x::AbstractToken, y)
    (|)(x, y::AbstractToken)
    (|)(x::AbstractToken, y::AbstractToken)

Operator syntax for `sEither(x, y)`.

```jldoctest
julia> 'a' | CharIn("AB") | "bc"
|🗄... Either
├─ a
├─ [AB] CharIn
└─ bc
::Union{Char, SubString}

```

"""
(|)(x::ParserTypes, y::ParserTypes) = sEither(x,y)

"""
    (|)(x::AbstractToken{T}, default::Union{T,Missing})

Operator syntax for `Optional(x, default=default)`.

```jldoctest
julia> parser("abc") | "nothing"
|🗄... Either
├─ abc
└─ nothing
::SubString

```

"""
function (|)(x::AbstractToken{T}, default::Union{T,Missing}) where { T }
    Optional(x,default=default)
end
function (|)(x::Char, y::Char)
    CharIn(tuple(x,y))
end
function (|)(x::CharIn, y::Char)
    CharIn(tuple(x.sets...,y))
end


"""
    `(|)(x::Either, T::Type)`

Return new Either with `T` added to result_type(x).
todo: Note that the options array is kept. As a consequence `push!`on result will also push to `x`.
"""
(|)(x::Either, T::Type) =
    Either{Union{result_type(x),T}}(x.options)

