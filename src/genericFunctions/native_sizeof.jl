# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    native_sizeof(x)::Integer

The byte size of the type x in a METOP native product.
# Example
```julia-repl
julia> native_sizeof(RecordHeader)
20
```
"""
native_sizeof(T::Type{<:Tuple})::Integer = sizeof(T)
native_sizeof(T::Type)::Integer = error("not implemented for $T")
native_sizeof(T::Type{<:Number})::Integer = sizeof(T)

native_sizeof(T::Type{<:RecordSubType})::Integer = sum(native_sizeof.(T, fieldnames(T)))
native_sizeof(T::Type{<:BinaryRecord})::Integer = sum(native_sizeof.(T, fieldnames(T)))

function native_sizeof(T::Type, field_name::Symbol)::Integer
    f_type = fieldtype(T, field_name)
    if f_type <: AbstractArray
        element_size = native_sizeof(eltype(f_type))
        array_length = _get_array_length(T, field_name)
        return element_size * array_length
    else
        return native_sizeof(f_type)
    end
end

# Array helpers
_get_array_length(T::Type, field_name::Symbol) = prod(get_raw_format_dim(T, field_name))

function _get_array_size(T::Type, field_name::Symbol)
    f_type = fieldtype(T, field_name)
    total_dims = ndims(f_type)
    return get_raw_format_dim(T, field_name)[1:total_dims]
end
