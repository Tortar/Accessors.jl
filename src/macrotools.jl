using MacroTools

const STRUCTSYMBOL = VERSION < v"0.7-" ? :type : :struct

function parse_error(ex)
    throw(ArgumentError("Cannot parse typedefinition from $ex."))
end

function statements(ex)
    exprs = []
    if isexpr(ex, :block)
        append!(exprs, vcat(map(statements, ex.args)...))
    else
        push!(exprs, ex)
    end
    return exprs
end

function splittypedef(ex)
    ex = MacroTools.striplines(ex)
    d = Dict{Symbol, Any}()
    if @capture(ex, struct header_ body__ end)
        d[:mutable] = false
    elseif @capture(ex, mutable struct header_ body__ end)
        d[:mutable] = true
    else
        parse_error(ex)
    end
    
    if @capture header nameparam_ <: super_
        nothing
    elseif @capture header nameparam_
        super = :Any
    else
        parse_error(ex)
    end
    d[:supertype] = super
    if @capture nameparam name_{param__}
        nothing
    elseif @capture nameparam name_
        param = []
    else
        parse_error(ex)
    end
    d[:name] = name
    d[:params] = param
    d[:fields] = []
    d[:constructors] = []
    for item in body
        if @capture item field_::T_
            push!(d[:fields], (field, T))
        elseif item isa Symbol
            push!(d[:fields], (item, Any))
        else
            append!(d[:constructors], statements(item))
        end
    end
    d
end


function combinetypedef(d)
    name = d[:name]
    parameters = d[:params]
    nameparam = isempty(parameters) ? name : :($name{$(parameters...)})
    header = :($nameparam <: $(d[:supertype]))
    fields = map(d[:fields]) do field
        fieldname, typ = field
        :($fieldname::$typ)
    end
    body = quote
        $(fields...)
        $(d[:constructors]...)
    end

    Expr(STRUCTSYMBOL, d[:mutable], header, body)
end

function combinefield(x)
    fieldname, T = x
    :($fieldname::$T)
end
