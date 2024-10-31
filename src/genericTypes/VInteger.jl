# Copyright (c) 2024 EUMETSAT
# License: MIT

struct VInteger{T <: Integer} <: RecordSubType
    scale::Int8
    raw_val::T
end

Base.float(x::VInteger)::Float64 = Float64(x.raw_val / 10.0^Int(x.scale))
