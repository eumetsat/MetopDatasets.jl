# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    native_read(io::IO, T)::T

Read a single object of type T from io to a file in the native Metop format. 
Endianness is automatically converted.

# Example
```julia-repl
julia> file_pointer = open("ASCA_SZO_1B_M03_20230329063300Z_20230329063556Z_N_C_20230329081417Z")
julia> main_header = MetopDatasets.native_read(file_pointer, MainProductHeader)
julia> main_header.sensing_start
2023-03-29T06:33:00
```
"""
function native_read(io::IO, T::Type)
    return error("Method missing for $T")
end

function native_read(io::IO, T::Type{<:Number})::T
    return ntoh(read(io, T))
end

function native_read(io::IO, T::Type{<:RecordSubType})::T
    return T((native_read(io, t) for t in fieldtypes(T))...)
end

function native_read(io::IO, T::Type{<:Record})::T
    return native_read(io, T, Val(fixed_size(T)))
end

function native_read(io::IO, T::Type{<:Record}, fixed_size::Val{true})::T
    return T((native_read(io, T, ft, n) for (ft, n) in zip(fieldtypes(T), fieldnames(T)))...)
end

function native_read(io::IO, T::Type{NTuple{N, UInt8}})::T where {N}
    return ntoh.(tuple((read(io, UInt8) for _ in 1:N)...))
end

## read fields only based on type for non-array fields
native_read(io::IO, parent_type::Type, T::Type, field_name::Symbol)::T = native_read(io, T)

## read fields based on type and array size for array fields

function native_read(
        io::IO, parent_type::Type, T::Type{<:AbstractArray}, field_name::Symbol)::T
    return native_read(io, parent_type, T, field_name, Val(fixed_size(parent_type)))
end

function native_read(
        io::IO, parent_type::Type, T::Type{<:AbstractArray},
        field_name::Symbol, fixed_size::Val{true})::T
    array_size = _get_array_size(parent_type, field_name)
    return native_read_array(io, T, array_size)
end

function native_read_array(io::IO, T::Type, array_size)::T
    A = [native_read(io, eltype(T)) for _ in 1:prod(array_size)]
    return reshape(A, array_size)
end

# Optimised function to read arrays of numbers
function native_read_array(
        io::IO, T::Type{<:AbstractArray{ET}}, array_size)::T where {ET <: Number}
    A = T(undef, array_size)
    read!(io, A)
    return ntoh.(A)
end

## Flexible sizes 

function native_read(
        io::IO, parent_type::Type, T::Type{<:AbstractArray},
        field_name::Symbol, fixed_size::Val{false})::T
    return error("Flexible record type $T is missing native_read method")
end

function native_read(io::IO, T::Type{<:Record}, fixed_size::Val{false})::T
    return native_read_flexible(io, T, Dict{Symbol, Int64}())
end

function native_read_flexible(io::IO, T::Type{<:Record},
        flexible_size_in)::T
    record_size_field = get_size_fields(T)
    flexible_size_mdr = Dict{Symbol, Int64}()

    vals = (_read_flex_field!(io, T, field_name,
                record_size_field, flexible_size_in, flexible_size_mdr) for field_name in fieldnames(T))

    return T(vals...)
end

function _read_flex_field!(
        io::IO, parent_type::Type, field_name::Symbol, record_size_field,
        flexible_size_fixed, flexible_size_mut)
    return _read_flex_field!(io::IO, parent_type::Type, fieldtype(parent_type, field_name),
        field_name, record_size_field,
        flexible_size_fixed, flexible_size_mut)
end

function _read_flex_field!(io::IO, parent_type::Type, T::Type{<:AbstractArray},
        field_name::Symbol, record_size_field,
        flexible_size_fixed, flexible_size_mut)::T
    array_size_raw = _get_array_size(parent_type, field_name)
    array_size = Tuple((_lookup_flexible_dim(dim_i, flexible_size_fixed, flexible_size_mut)
    for dim_i in array_size_raw))
    return native_read_array(io, T, array_size)
end

function _read_flex_field!(io::IO, parent_type::Type, T::Type{<:Integer},
        field_name::Symbol, record_size_field,
        flexible_size_fixed, flexible_size_mut)::T
    field_val = native_read(io, T)

    if haskey(record_size_field, field_name)
        k = record_size_field[field_name]
        flexible_size_mut[k] = field_val
    end

    return field_val
end

function _read_flex_field!(
        io::IO, parent_type::Type, T::Type, field_name::Symbol, record_size_field,
        flexible_size_fixed, flexible_size_mut)::T
    return native_read(io, T)
end

_lookup_flexible_dim(dim_size::Integer, size_dict1::Dict, size_dict2::Dict)::Int64 = dim_size

function _lookup_flexible_dim(dim_size::Symbol, size_dict1::Dict, size_dict2::Dict)::Int64
    if haskey(size_dict1, dim_size)
        return size_dict1[dim_size]
    elseif haskey(size_dict2, dim_size)
        return size_dict2[dim_size]
    else
        @show size_dict1
        @show size_dict2
        error("Could not find flexible dimension $dim_size")
    end
end
