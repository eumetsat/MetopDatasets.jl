# Copyright (c) 2024 EUMETSAT
# License: MIT

_get_convert_type(T::Type) = T
_get_convert_type(::Type{<:CdsTime}) = Float64
_get_convert_type(::Type{<:VInteger}) = Float64
function _get_convert_type(::Type{BitString{NBytes}}) where {NBytes}
    return _bitstring_convert_type(NBytes)
end

function _get_convert_type(T::Type{<:RecordSubType})
    @warn "No conversion for $T. This can cause issues when converting MetopDataset to netCDF "
    return T
end

_auto_convert(T::Type, val) = convert(T, val)
_auto_convert(::Type{Float64}, val::CdsTime)::Float64 = seconds_since_epoch(val)
_auto_convert(::Type{Float64}, val::VInteger)::Float64 = float(val)
_auto_convert(::Type{String}, val::BitString)::String = join(bitstring.(val.bytes))
