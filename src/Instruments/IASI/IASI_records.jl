# Copyright (c) 2024 EUMETSAT
# License: MIT

IASI_xxx_1C_V11_format = joinpath(@__DIR__, "csv_formats/IASI_xxx_1C_V11.csv")

abstract type IASI_XXX_1C <: DataRecord end
# create data structure, add description and scale factors
eval(record_struct_expression(IASI_xxx_1C_V11_format, IASI_XXX_1C))

function data_record_type(header::MainProductHeader, product_type::Val{:IASI_xxx_1C})::Type
    if header.format_major_version == 11
        return IASI_XXX_1C_V11
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

IASI_SND_02_V11_format = joinpath(@__DIR__, "csv_formats/IASI_SND_02_V11.csv")

abstract type IASI_SND_02 <: DataRecord end
# create data structure, add description and scale factors
eval(record_struct_expression(IASI_SND_02_V11_format, IASI_SND_02))

function data_record_type(header::MainProductHeader, product_type::Val{:IASI_SND_02})::Type
    if header.format_major_version == 11
        return IASI_SND_02_V11
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

function get_dim_fields(::Type{<:IASI_SND_02})
    return Dict(
        :nerr => :NERR,
        :co_nbr => :CO_NBR,
        :hno3_nbr => :HNO3_NBR,
        :o3_nbr => :O3_NBR
    )
end

function get_flexible_dims_file(file_pointer::IO, T::Type{<:IASI_SND_02})
    pos = position(file_pointer)
    seekstart(file_pointer)
    giard = read_first_record(file_pointer, GIADR_IASI_SND_02_V11)
    flexible_dims_file = get_iasi_l2_flex_size(giard)
    seek(file_pointer, pos)
    return flexible_dims_file
end

function get_missing_value(T::Type{<:IASI_SND_02}, field::Symbol)
    return get_missing_value(T, _get_field_eltype(T, field))
end
get_missing_value(::Type{<:IASI_SND_02}, field_type::Type{<:Unsigned}) = typemax(field_type)
get_missing_value(::Type{<:IASI_SND_02}, field_type::Type{<:Signed}) = typemin(field_type)

function get_missing_value(::Type{<:IASI_SND_02}, ::Type{BitString{N}}) where {N}
    content = Tuple((typemax(UInt8) for _ in 1:N))
    return BitString{N}(content)
end

function get_missing_value(record_type::Type{<:IASI_SND_02}, ::Type{VInteger{T}}) where {T}
    return VInteger(typemin(Int8), get_missing_value(record_type, T))
end
