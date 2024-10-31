# Copyright (c) 2024 EUMETSAT
# License: MIT

struct BitString{NBytes} <: RecordSubType
    bytes::NTuple{NBytes, UInt8}
end

function BitString(bytes::AbstractVector)
    n_bytes = length(bytes)
    return BitString{n_bytes}(Vector{n_bytes, UInt8}(bytes))
end

## Helper functions
Base.string(x::BitString) = join(bitstring.(x.bytes))

function Base.show(io::IO, x::BitString)
    return println(io, string(x))
end

function Base.convert(T::Type{<:Unsigned}, x::BitString{NBytes}) where {NBytes}
    @assert NBytes <= sizeof(T)
    padded_byte_array = zeros(UInt8, sizeof(T))

    # zero pad from the front since the values are stored as big-endian
    padding = sizeof(T) - NBytes
    padded_byte_array[(1 + padding):end] .= x.bytes

    val = only(reinterpret(T, padded_byte_array))
    return ntoh(val)
end

function _bitstring_convert_type(NBytes)
    if NBytes == 1
        return UInt8
    elseif NBytes == 2
        UInt16
    elseif NBytes <= 4
        UInt32
    elseif NBytes <= 8
        UInt64
    elseif NBytes <= 16
        UInt128
    else
        return String
    end
end

function uinteger(x::BitString{NBytes}) where {NBytes}
    new_type = _bitstring_convert_type(NBytes)

    if new_type <: Unsigned
        return convert(new_type, x)
    else
        error("Can't convert $NBytes to UInt")
    end
end
