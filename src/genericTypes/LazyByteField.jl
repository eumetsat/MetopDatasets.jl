# Copyright (c) 2025 EUMETSAT
# License: MIT

"""
    LazyByteField <: AbstractVector{Vector{UInt8}}

Type to read fields from records as a byte vector
Note that LazyByteField does not work with conversion to netCDF.
"""
struct LazyByteField <: AbstractVector{Vector{UInt8}}
    file_pointer::IOStream
    offsets::Vector{Int64}
    field_size::Vector{Int64}
end

Base.size(a::LazyByteField) = (length(a.offsets),)

function Base.getindex(a::LazyByteField, i::Integer)
    seek(a.file_pointer, a.offsets[i])
    out = Array{UInt8}(undef, a.field_size[i])
    read!(a.file_pointer, out)
    return out
end
