module Tokens
############################################################
## Tokens
using Nullables
using BasePiracy
import BasePiracy: construct
## TODO: move intenring into parsing (creating from a db interning in tokens wastes mem)
export AbstractToken, variable, value
export Token, TokenValue, TokenTuple, TokenString
import Base: ==, hash

abstract type AbstractToken end

variable(x::AbstractToken) = error("implement variable $(typeof(x))")
value(x::AbstractToken) = error("implement value $(typeof(x))")
label(x::AbstractToken) = error("implement label $(typeof(x))")


variable_colors=Dict(
    :ext => 36,
    :macro => 36,
    :number => 36,
    :operator => :yellow,
    :name => :yellow,
    :footnote => :yellow,
    :type => :red,
    :field => :light_red,
    :ellipsis => :grey,
    :whitespace => :grey,
    :list => :light_black,
    :Symbol => :yellow,
    :String => :yellow,
    :paren => :light_black,
    :quote => :light_black,
    Symbol("wikt:de") => :light_blue,
    :htmlcomment => :light_black,
    :meaning => :light_black
)

export value_empty
value_empty(x::Pair) = value_empty(x.second) ## needed in tryparsenext
value_empty(x::Vector) = isempty(x)
value_empty(x) = false
value_empty(::Union{Nothing,Missing}) = true
value_empty(x::String) = x==""
value_empty(x::AbstractToken) = value(x) === missing || value(x)==""

function Base.show(io::IO, z::AbstractToken)
    color=get(variable_colors,
              Symbol(variable(z)), 36)
    if variable(z)==:literal || variable(z)==:delimiter
        value(z)!==missing && print(io,value(z))
    elseif !isinformative(z)
        printstyled(io, value(z); bold=true,
                    color=:darkgray)
    elseif value(z)===missing ## || value(z)==""
        printstyled(io, variable(z); bold=true,
                    color=color)
    else
        col=get(variable_colors, variable(z), missing)
        if variable(z) == :macro
            printstyled(
                io, "{{{", value(z),"}}}";
                bold=true, color=color
            )
        elseif col === missing 
            printstyled(
                io, "[[",variable(z), "][", value(z),"]]";
                bold=true, color=color
            )
        else
            printstyled(
                io, value(z);
                bold=true, color=color
            )
        end
    end
end

             
export TokenPair
struct TokenPair{K,V} <: AbstractToken
    key::K
    value::V
end
==(x::TokenPair,y::TokenPair) =
    x.key==y.key && x.value==y.value
hash(x::TokenPair, h::UInt) = hash(x.key, hash(x.value,h))
BasePiracy.construct(::Type{TokenPair{K,V}}; key, value) where {K,V} =
    TokenPair{K,V}(_convert(K,key), _convert(V,value))
BasePiracy.construct(::Type{TokenPair{K,Vector{V}}}; key, value=V[]) where {K,V} =
    TokenPair{K,Vector{V}}(_convert(K,key), _convert(Vector{V},value))
parentheses = Dict{Any,Any}(:paren=>("(", ")"),
                            :bracket=>("[", "]"),
                            :curly=>("{", "}"),
                            :angle=>("<", ">"),
                            :quote=>("\"","\""),
                            :squote=> ("'","'"),
                            :german_quote => ("„","“"),
                            :htmlcomment=> ("<!--","-->"),
                            )
import Base: with_output_color
function Base.show(io::IO, z::TokenPair)
    inner_print(io::IO,x::AbstractVector) =
        for t in x; print(io, t); end
    inner_print(io::IO,x) =
        print(io, x)
    
    if z.key==:italics
        with_output_color(inner_print, :underline, io, z.value)
    elseif z.key==:bold
        with_output_color(inner_print, :bold, io, z.value)
    elseif z.key==:bolditalics
        with_output_color(inner_print, :bold, io, z.value)
    else
        open, close = get(parentheses, z.key, (z.key,z.key))
        print(io, open)
        inner_print(io,z.value)
        print(io, close)
    end
end



export Token
struct Token <: AbstractToken
    name::Symbol ## todo: CategoricalArrays.CategoricalValue
    value::String
    function Token(name::Symbol, value::T) where {T<:AbstractString}
        new(name, value)
    end
end
Token(name::Symbol, value::Union{Missing, Nothing}) = Token(name, "")
Token(name::Symbol) = Token(name, "")
Token(x::Pair) = Token(x.first, x.second)
Token(x::Token) = x
function Token(name::AbstractString, value)
    Token(Symbol(name), value)
end
import Base: convert
Base.convert(::Type{Token},e::Pair) =
    Token(Symbol(e.first), e.second)

export @l_str, @ws_str, @delim_str, @T
macro T(name, value)
    Token(name, string(value))
end
macro l_str(x)
    Token(:literal, x)
end
macro ws_str(x)
    Token(:whitespace, x)
end
macro delim_str(x)
    Token(:delimiter, x)
end
ws(x) = Token(:whitespace, x)



export NamedString
"parametrized Token struct -- dangerously slow!"
struct NamedString{name} <: AbstractToken
    value::String
    function NamedString(name, value)
        new{Symbol(name)}(value)
    end
    function NamedString(x::Token)
        new{variable(x)}(value(x))
    end
end
function NamedString(x::NamedString)
    x
end
Base.convert(::Type{NamedString}, x::Token) =
    NamedString(variable(x),value(x))

Base.show(io::IO,x::NamedString{:type}) =
    print(io,Token(:type,x.value),".")

Base.show(io::IO,x::NamedString{:field}) =
    print(io,Token(:field,x.value),"=")

Base.show(io::IO,x::NamedString{:whitespace}) =
    printstyled(io,x.value; color=:underline)


Base.propertynames(x::NamedString) = _fieldnames(typeof(x))
Base.getproperty(x::NamedString, p::Symbol) =
    if p == :name
        variable(x)
    elseif p == :value
        value(x)
    else
        error("no field $p in NamedString")
    end

BasePiracy._fieldnames(x::Type{<:NamedString}) = (:name,:value)
BasePiracy._fieldtypes(x::Type{<:NamedString}) = (Symbol,String)
BasePiracy._fieldtype(x::Type{<:NamedString}, p::Symbol) =
    if p == :name
        Symbol
    elseif p == :value
        String
    else
        error("no field $p in NamedString")
    end

variable(x::NamedString{name}) where name = name
value(x::NamedString) = getfield(x,1)
==(x::NamedString,y::NamedString) =
    variable(x)==variable(y) && value(x)==value(y)
hash(x::NamedString, h::UInt) = hash(variable(x), hash(value(x),h))

export Node
struct Node{T} <: AbstractToken
    name::Symbol
    attributes::Vector{Token}
    children::Vector{T}
    function Node(name::Symbol, attrs, value)
        new{eltype(value)}(name, attrs,value)
    end
    function Node(name::AbstractString, attrs, value)
        new{eltype(value)}(Symbol(name), attrs,value)
    end
    function Node{T}(name::AbstractString, attrs, value) where T
        new{T}(Symbol(name), attrs, _convert(Vector{T},value))
    end
end
BasePiracy.construct(::Type{Node{T}}; name, attributes=Token[], children=T[]) where T = 
    Node(name,
         _convert(Vector{Token},attributes),
         children)
==(a::Node, b::Node) = a.name==b.name && a.attributes==b.attributes && a.children==b.children
hash(x::Node, h::UInt) = hash(x.name, hash(x.attributes, hash(x.children,h)))
function Base.show(io::IO, x::Node) where {T}
    print(io,"<$(x.name)")
    for a in x.attributes
        print(io," ", variable(a), "=\"", value(a), "\"")
    end
    if !isempty(x.children)        
        print(io,">")
        for c in x.children
            print(io,c)
        end
        print(io,"</$(x.name)>")
    else
        print(io,"/>")
    end
end



export ReferringToken
struct ReferringToken{Tt, Tv, I} <: AbstractToken
    name::Tt
    value::Tv
    reference::I
end
value(x::Union{Token, TokenPair, ReferringToken}) = x.value
variable(x::Union{Token, ReferringToken}) = x.name
variable(x::TokenPair) = x.key



export TokenString
const TokenString = Vector{<:AbstractToken}

# @deprecate TokenString(x...) tokenize(x...)

# const TokenTuple = Tuple{Vararg{Token, N} where N}
# TokenString{Tt, T} = Tuple{Vararg{Token{t,T} where {t <:Tt}, N} where N}
# TokenNest{Tv} = Tuple{Vararg{Union{TokenTuple{t},Token{t,s}} where {t, s <:Tv}, N} where N}
## TokenTuple(x::AbstractToken{Any, Tv}...) where {Tv} = x
# TokenString(x::TokenTuple) = x



export Line, Paragraph, Body

export LinePrefix
struct LinePrefix{I}
    prefix::Vector{I}
end
==(x::LinePrefix,y::LinePrefix) =
    x.prefix == y.prefix
Base.hash(x::LinePrefix,h::UInt) =
    hash(x.prefix,h)
Base.lastindex(x::LinePrefix) =
    lastindex(x.prefix)
Base.length(x::LinePrefix) =
    length(x.prefix)
Base.isempty(x::LinePrefix) =
    isempty(x.prefix)
Base.iterate(x::LinePrefix, a...) =
    iterate(x.prefix, a...)
Base.getindex(x::LinePrefix, a...) =
    getindex(x.prefix, a...)
Base.convert(::Type{Vector{I}}, x::LinePrefix{J}) where {I,J} =
    convert(Vector{I}, x.prefix)
Base.convert(::Type{LinePrefix{J}}, x::Vector{I}) where {I,J} =
    LinePrefix{J}(convert(Vector{J}, x))
Base.pushfirst!(v::LinePrefix, x) where {J} =
    pushfirst!(v.prefix,x)
Base.push!(v::LinePrefix, x) where {J} =
    push!(v.prefix,x)


struct Line{I,T}
    prefix::LinePrefix{I}
    tokens::Vector{T}
end
BasePiracy.construct(::Type{Line{I,T}};prefix=I[],tokens=T[]) where {I,T} =
    Line{I,T}(prefix,tokens)

Line(t::Vector{T}) where {T} =
    Line{NamedString}(t)
Line{I}(t::Vector{T}) where {I,T} =
    Line(I[],t)
function Line(prefix::Vector{I}, t::Vector{T}) where {I,T}
    Line{I,T}(LinePrefix{I}(prefix), t)
end
function Line(prefix::Vector{I}, t::Vector{T}, newline::AbstractString) where {I,T}
    Line( prefix,
          vcat(t, Token(:whitespace, newline)))
end
function Line(prefix::NTuple{N,NamedString}, t::Vector{T}) where {N,T}
    Line{NamedString,T}(
        LinePrefix{NamedString}(NamedString[prefix...]),
        t)
end
==(a::Line, b::Line) = a.prefix==b.prefix && a.tokens== b.tokens
hash(x::Line, h::UInt) = hash(x.prefix, hash(x.tokens))
import Base: convert
Base.convert(::Type{Line{I,T}}, x::Line{J,S}) where {I,J,S,T} =
    Line(convert(Vector{I}, x.prefix), convert(Vector{T}, x.tokens))
Base.convert(::Type{Line{I,T}}, x::Vector) where {I,T} =
    Line(I[], convert(Vector{T}, x))

function Base.show(io::IO, i::Line{I,T}) where {I,T}
    if !isempty(i.prefix) && variable(i.prefix[1]) == :headline
        level = parse(Int, value(i.prefix[1]))
        wikihead = repeat("=", level)
        print(io, wikihead, " ")
        tail = Token[]
        for x in i.tokens
            if !isequal(x, Token(:whitespace,"\n"))
                print(io, x)
            else
                push!(tail,x)
            end
        end
        print(io, wikihead)
        for x in tail
            print(io, x)
        end 
    else
        for x in i.prefix
            print(io, x.value === missing ? "" : x)
        end
        for x in i.tokens
            print(io, x)
        end
    end
end


Paragraph{I,T} = Vector{Line{I,T}}
Paragraph(x::Paragraph) = x
## Base.show(io::IO, v::Type{Paragraph{T}}) where T = print(io, "Paragraph{$T}")
Base.show(io::IO, v::AbstractVector{<:Line}) =
    for x in v
        print(io,x)
    end

Body{I,T} = Vector{Paragraph{I,T}}
## Base.show(io::IO, v::Type{Body{T}}) where T = print(io, "Body{$T}")
Base.show(io::IO, v::Body) =
    for x in v
        print(io,x)
    end
# Base.show(io::IO, m::MIME"text/markdown", x::Token) =
#     if x.name in [ :literal, :delimiter, :whitespace ]
#         print(io, x.value)
#     else
#         print(io,"""[$(x.value)]($(x.name) "$(x.name)")""")
#     end
# Base.show(io::IO, m::MIME"text/markdown", x::Line) = println(io,m,x.indent,x.tokens...)
# Base.show(io::IO, m::MIME"text/markdown", x::Vector{Line}) = println(io,m,x...)
# Base.show(io::IO, m::MIME"text/markdown", x::Vector{Vector{Line}}) = println(io,m,x...)

export Template, LineContent
TemplateArgument{I,T} = Pair{String,Vector{Line{I,T}}}
struct Template{I,T} <: AbstractToken
    template::String
    arguments::Vector{TemplateArgument{I,T}}
    Template(t,a::Vector{TemplateArgument{I,T}}) where {I,T} =
        new{I,T}(t,[ k => v for (k,v) in a])
    Template{I,T}(t,a::Vector) where {I,T} =
        new{I,T}(t,[ k => convert(Vector{Line{I,T}},v) for (k,v) in a])
    Template(t,a::Vector) =
        new{Any,Any}(t,[ k => v for (k,v) in a])
end
BasePiracy.construct(::Type{Template{I,T}};template,arguments=TemplateArgument{I,T}[]) where {I,T} =
    Template{I,T}(template,arguments)
Template(a::String) = Template(a,TemplateArgument{Token,LineContent}[])
==(a::Template, b::Template) = a.template==b.template && a.arguments==b.arguments
hash(x::Template, h::UInt) = hash(x.template, hash(x.arguments,h))

function Base.show(io::IO, x::Template) where T 
    print(io, "{{")
    print(io, x.template)
    for a in x.arguments
        print(io, "|")
        if a isa Pair
            if !isempty(a.first)
                print(io, a.first,"=",a.second)
            else
                print(io, a.second)
            end
        else
            print(io, a)
        end        
    end
    print(io, "}}")
end

LineContent = AbstractToken

export isinformative, isvariable
isinformative(i) = true
isinformative(i::Token)  =
    !(variable(i) in [ :delimiter, :indent, :list, :enum, :whitespace ])
isinformative(i::Template)  = true
isvariable(i::AbstractToken)  =
    !(variable(i) in [ :literal ]) && isinformative(i)

emptyLine(x::Vararg{T}) where T = Line{T,T}([ Token(:whitespace,"") ],
                                   T[x...])


export tokens
tokens(x::Vector{<:Union{AbstractToken, AbstractString, Symbol}}) =
    Iterators.repeated(1  => x, 1)
tokens(x::Union{Number,Symbol, AbstractString, AbstractToken}) =
    Iterators.repeated(1 => Iterators.repeated(x, 1), 1)
## tokens(d::Dict{Symbol,<:AbstractString}) =
##     [ 1 => [ Token(x.first, x.second) for x in d ] ]
tokens(d::Dict) =
    [] #Iterators.flatten( tokens(x.second) for x in d )
tokens(x::Vector) =
    Iterators.flatten(tokens(y) for y in x)

function tokens(n::NamedTuple{names,t}) where {names,t}    
    val(field) = tokens(getproperty(n,field))
    R = Iterators.flatten( val(field)
                           for field in names
                           # if !isempty(val(field))
                           )
    R
    # Pair[ w => collect(v) for (w,v) in R ]    
end

function tokens(n::T) where {T}
    val(field) = tokens(getfield(n,field))
    R = Iterators.flatten( val(field)
                           for field in fieldnames(T)
                           # if !isempty(val(field))
                           )
    R
    # Pair[ w => collect(v) for (w,v) in R ]    
end







import ..ParserAlchemy: result_type, instance, rep, seq, alt, regex_string, parenthesisP
import ..ParserAlchemy: enum_label, parser, word, delimiter, quotes, extension
bracket_number = instance(
    Token, (v,i) -> Token(:number, v),
    r"^\[(?:(?:[0-9]+[[:alpha:]]*(?:,|–|-) *)*(?:[0-9]+[[:alpha:]]* *)|\*)\]");

## TODO: merge with bracket_number, tokenize parts
bracket_reference = instance(
    Token, (v,i) -> Token(:reference, v),
    r"^\[(?:(?:[0-9]+[[:alpha:]]*(?:,|–|-) *)*(?:[0-9]+[[:alpha:]]* *))\]");

default_tokens = [
    instance(Token, parser(Regex(" "*regex_string(enum_label)*" ")), :number),
    instance(Token, parser(word), :literal),
    instance(Token, parser(quotes), :quote),
    instance(Token, parser(delimiter), :delimiter)
]
tokenstring =
    #tok(inline, 
    rep(alt(bracket_number, bracket_reference, default_tokens...,
            instance(Token, r"[][{}()<>]", :paren)))

append_element_f(vp, ep; kw...) =
    let T=result_type(vp)
        seq(T, vp, ep;
            transform = (v,i) -> convert(T, [ v[1]..., v[2] ]),
            ## log=true,
            kw...)
    end

filename    = alt(
    append_element_f(tokenstring, instance(Token, parser(extension), :ext) ; combine=true),
    append_element_f(tokenstring, instance(Token, parser("/"), :ext); combine=true),
    append_element_f(tokenstring, instance(Token, parser(""), :ext))
)

import ..ParserAlchemy: tokenize
tokenize(x) = tokenize(tokenstring, x)


import Base: convert
Base.convert(::Type{TokenString}, x::String) = tokenize(x)

## import ..Tokens: Token, Template, TokenPair, Line, LineContent, Paragraph

import TextParse

export IteratorParser
struct IteratorParser{T} <: TextParse.AbstractToken{T}
    label::String
    match::Function
    f::Function    
end
Base.show(io::IO, x::IteratorParser) = print(io, x.label)

function TextParse.tryparsenext(tok::IteratorParser{T},
                                str, i, till,
                                opts=TextParse.default_opts) where {P,T}
    ##@show typeof(str[i])
    if i<=lastindex(str) && tok.match(str[i]) 
        Nullable{T}(tok.f(str[i], i)), nextind(str,i)
    else
        Nullable{T}(), i
    end
end

export is_type, is_heading, is_template, is_template_line, is_line
is_template(template::String, transform=(v,i) -> v) =
    IteratorParser{Line{NamedString,LineContent}}(
        template,
        x->x isa Template
        && x.name==template,
        transform
    )
is_template_line(template::String, transform=(v,i) -> v, T = Line{NamedString,LineContent}) =
    IteratorParser{T}(
        template,
        x->(x) isa Line && !isempty(x.tokens)
        && (x.tokens[1]) isa Template
        && x.tokens[1].template==template,
        transform)
is_template_line(pred::Function, transform=(v,i) -> v, T = Line{NamedString,LineContent}) =
    is_template_line(T, pred, transform)
is_template_line(T::Type, pred::Function, transform=(v,i) -> v) =
    IteratorParser{T}(
        "template",
        x->(x) isa Line && !isempty(x.tokens)
        && (x.tokens[1]) isa Template
        && pred(x.tokens[1]),
        transform)
is_heading(f=x->true, transform=(v,i) -> v, T = Line{NamedString,LineContent}) =
    IteratorParser{T}(
        "heading",
        x->x isa Line
        && !isempty(x.prefix)
        && variable(x.prefix[end])==:headline
        && f(x.prefix[end]),
        transform)
is_type(t::Type, transform=(v,i) -> v) =
    IteratorParser{t}(string(t), x->x isa t,
                      transform)
is_line(transform=(v,i) -> v) = is_line(Line{NamedString,LineContent}, transform)

"""
is not a headline
"""
is_line(t::Type, transform=(v,i) -> v) =
    IteratorParser{t}("Line", x->x isa Line
                      && ( isempty(x.prefix) || variable(x.prefix[end])!=:headline),
                      transform)

include("lines.jl")

end
