# Copyright (c) 2024 EUMETSAT
# License: MIT

const IASI_xxx_1C_V11_format = @path joinpath(@__DIR__, "csv_formats/IASI_xxx_1C_V11.csv")

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

######### Level 1 Principal Component Scores (PCS) ###########

abstract type IASI_PCS_1C <: DataRecord end

const IASI_PCS_1C_V10_format = @path joinpath(@__DIR__, "csv_formats/IASI_PCS_1C_V10.csv")

# create data structure, add description and scale factors
eval(record_struct_expression(IASI_PCS_1C_V10_format, IASI_PCS_1C))

function data_record_type(header::MainProductHeader, product_type::Val{:IASI_PCS_1C})::Type
    if header.format_major_version == 10
        return IASI_PCS_1C_V10
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

_get_giard_type(::Type{IASI_PCS_1C_V10}) = GIADR_IASI_PCS_1C_V10

function _get_flexible_dims_file(file_pointer::IO, T::Type{IASI_PCS_1C_V10})
    return get_flexible_dims_from_giard(file_pointer, T)
end

function get_flexible_dim_fields(::Type{IASI_PCS_1C_V10})
    return OrderedDict{Symbol, Symbol}(
    )
end

function get_eigenvector_file_name(ds, band_n)
    return read_single_record(ds.file_pointer, GlobalExternalAuxiliary, band_n).content
end

######### level 2###########
const IASI_L2_V10_ERROR_DATA_NAME = :error_data
const IASI_L2_V10_ERROR_DATA_DESCRIPTION = "Contents depend on MDR.FLG_STER field (Data is not parsed)"

abstract type IASI_SND_02 <: DataRecord end

const IASI_SND_02_V11_format = @path joinpath(@__DIR__, "csv_formats/IASI_SND_02_V11.csv")
const IASI_SND_02_V10_format = @path joinpath(@__DIR__, "csv_formats/IASI_SND_02_V10.csv")

# create data structure, add description and scale factors
eval(record_struct_expression(IASI_SND_02_V11_format, IASI_SND_02))
eval(record_struct_expression(IASI_SND_02_V10_format, IASI_SND_02))

function data_record_type(header::MainProductHeader, product_type::Val{:IASI_SND_02})::Type
    if header.format_major_version == 11
        return IASI_SND_02_V11
    elseif header.format_major_version == 10
        return IASI_SND_02_V10
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

function get_flexible_dim_fields(::Type{IASI_SND_02_V11})
    return OrderedDict(
        :nerr => :NERR,
        :co_nbr => :CO_NBR,
        :hno3_nbr => :HNO3_NBR,
        :o3_nbr => :O3_NBR
    )
end

function flexible_dim_data_location(::Type{IASI_SND_02_V11})
    return OrderedDict(
        :NERR => :error_data_index,
        :CO_NBR => :co_nfitlayers,
        :HNO3_NBR => :hno3_nfitlayers,
        :O3_NBR => :o3_nfitlayers
    )
end

function get_flexible_dim_fields(::Type{IASI_SND_02_V10})
    return OrderedDict{Symbol, Symbol}(
    )
end

_get_giard_type(T::Type{IASI_SND_02_V11}) = GIADR_IASI_SND_02_V11
_get_giard_type(T::Type{IASI_SND_02_V10}) = GIADR_IASI_SND_02_V10

function _get_flexible_dims_file(file_pointer::IO, T::Type{IASI_SND_02_V11})
    return get_flexible_dims_from_giard(file_pointer, T)
end
function _get_flexible_dims_file(file_pointer::IO, T::Type{IASI_SND_02_V10})
    return get_flexible_dims_from_giard(file_pointer, T)
end

# IASI_SND_02_V11  needs to have a fill value for VInteger and BitString
function get_missing_value(
        record_type::Type{IASI_SND_02_V11}, ::Type{VInteger{T}}, field::Symbol) where {T}

    # Only set missing value for variable fields to avoid masking real data
    if !fixed_size(record_type, field)
        return VInteger(typemin(Int8), get_missing_value(record_type, T, field))
    else
        return nothing
    end
end

function get_missing_value(
        record_type::Type{IASI_SND_02_V11}, ::Type{BitString{N}}, field::Symbol) where {N}

    # Only set missing value for variable fields to avoid masking real data
    if !fixed_size(record_type, field)
        content = Tuple((typemax(UInt8) for _ in 1:N))
        return BitString{N}(content)
    else
        return nothing
    end
end

### Common functions ####
function get_flexible_dims_from_giard(file_pointer::IO, T::Type{<:DataRecord})
    pos = position(file_pointer)
    seekstart(file_pointer)
    giard = read_first_record(file_pointer, _get_giard_type(T))
    flexible_dims_file = get_flexible_dims_from_giard(giard)
    seek(file_pointer, pos)
    return flexible_dims_file
end
