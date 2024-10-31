# Copyright (c) 2024 EUMETSAT
# License: MIT

get_record_class(::Type{<:MainProductHeader}) = 1
get_record_class(::Type{<:SecondaryProductHeader}) = 2
get_record_class(::Type{<:InternalPointerRecord}) = 3
get_record_class(::Type{<:GlobalInternalAuxillary}) = 5
get_record_class(::Type{<:DummyRecord}) = 8
get_record_class(::Type{<:DataRecord}) = 8

get_instrument_group(::Type{<:Record}) = nothing
get_instrument_group(::Type{<:DummyRecord}) = 13

get_instrument_subclass(::Type{<:Record}) = nothing
