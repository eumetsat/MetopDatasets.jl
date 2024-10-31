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
