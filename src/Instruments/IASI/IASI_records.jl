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

function get_flexible_dim_fields(::Type{<:IASI_SND_02})
    return Dict(
        :nerr => :NERR,
        :co_nbr => :CO_NBR,
        :hno3_nbr => :HNO3_NBR,
        :o3_nbr => :O3_NBR
    )
end

function _get_flexible_dims_file(file_pointer::IO, T::Type{<:IASI_SND_02})
    pos = position(file_pointer)
    seekstart(file_pointer)
    giard = read_first_record(file_pointer, GIADR_IASI_SND_02_V11)
    flexible_dims_file = get_iasi_l2_flex_size(giard)
    seek(file_pointer, pos)
    return flexible_dims_file
end

# IASI_SND_02 needs to have a fill value for VInteger and BitString
function get_missing_value(
        record_type::Type{<:IASI_SND_02}, ::Type{VInteger{T}}, field::Symbol) where {T}

    # Only set missing value for variable fields to avoid masking real data
    if !fixed_size(record_type, field)
        return VInteger(typemin(Int8), get_missing_value(record_type, T, field))
    else
        return nothing
    end
end

function get_missing_value(
        record_type::Type{<:IASI_SND_02}, ::Type{BitString{N}}, field::Symbol) where {N}

    # Only set missing value for variable fields to avoid masking real data
    if !fixed_size(record_type, field)
        content = Tuple((typemax(UInt8) for _ in 1:N))
        return BitString{N}(content)
    else
        return nothing
    end
end
