# Copyright (c) 2024 EUMETSAT
# License: MIT

########### CSV format paths ###########
const GOME_xxx_1B_EARTHSHINE_V13_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_EARTHSHINE_V13.csv")
const GOME_xxx_1B_EARTHSHINE_V12_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_EARTHSHINE_V12.csv")
const GOME_xxx_1B_SUN_V13_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_SUN_V13.csv")
const GOME_xxx_1B_SUN_V12_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_SUN_V12.csv")
const GOME_xxx_1B_MOON_V13_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_MOON_V13.csv")
const GOME_xxx_1B_MOON_V12_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_MOON_V12.csv")
const GOME_xxx_1B_CALIBRATION_V13_format = @path joinpath(
    @__DIR__, "csv_formats/GOME_xxx_1B_CALIBRATION_V13.csv")
const GOME_xxx_1B_CALIBRATION_V12_format = @path joinpath(
    @__DIR__, "csv_formats/GOME_xxx_1B_CALIBRATION_V12.csv")

########### Record types ###########
abstract type GOME_XXX_1B <: DataRecord end

"""
    GOME_XXX_1B_ROOT

Sentinel data-record type parameterising the root `MetopDataset` of a GOME-2 L1B
product. The root dataset exposes no variables itself; the MDR subclasses present in
the file are accessed as groups (`"earthshine"`, `"calibration"`, `"sun"`, `"moon"`).
"""
abstract type GOME_XXX_1B_ROOT <: GOME_XXX_1B end
struct GOME_XXX_1B_ROOT_V13 <: GOME_XXX_1B_ROOT end
struct GOME_XXX_1B_ROOT_V12 <: GOME_XXX_1B_ROOT end

eval(record_struct_expression(GOME_xxx_1B_EARTHSHINE_V13_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_EARTHSHINE_V12_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_SUN_V13_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_SUN_V12_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_MOON_V13_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_MOON_V12_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_CALIBRATION_V13_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_CALIBRATION_V12_format, GOME_XXX_1B))

# N_GEO_BANDS is a symbolic dim shared across MDR CSVs; it forces FlexibleRecordLayout
# (MDR records are variable-size in the file).
function MetopDatasets._get_flexible_dims_file(::IO, ::Type{<:GOME_XXX_1B})
    return OrderedDict{Symbol, Int64}(:N_GEO_BANDS => 10)
end

MetopDatasets.get_flexible_dim_fields(::Type{<:GOME_XXX_1B}) = OrderedDict{Symbol, Symbol}()

# L1B MDR subclass IDs: 6=Earthshine, 7=Calibration, 8=Sun, 9=Moon.
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_EARTHSHINE_V13}) = 6
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_EARTHSHINE_V12}) = 6
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_SUN_V13}) = 8
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_SUN_V12}) = 8
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_MOON_V13}) = 9
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_MOON_V12}) = 9
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_CALIBRATION_V13}) = 7
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B_CALIBRATION_V12}) = 7

# Only the Earthshine MDR interpolates a variable GEO_EARTH_ACTUAL block between the
# fixed header and the REC_LENGTH/NUM_RECS dynamic prefix; the spectral parser branches on this.
has_geo_earth_actual_prefix(::Type) = false
has_geo_earth_actual_prefix(::Type{<:GOME_XXX_1B_EARTHSHINE_V13}) = true
has_geo_earth_actual_prefix(::Type{<:GOME_XXX_1B_EARTHSHINE_V12}) = true

# Raw-record API is disabled — MDR structs only model fixed-header fields; the variable
# spectral payload is not part of the generated struct.
function _gome2_raw_record_api_error(record_type::Type{<:GOME_XXX_1B})
    return error("Raw-record API is disabled for $record_type. " *
                 "Use MetopDataset variables (e.g. ds[\"radiance_1a\"]) instead.")
end

function read_single_record(::IO, record_type::Type{<:GOME_XXX_1B}, ::Integer)
    return _gome2_raw_record_api_error(record_type)
end
function read_single_record(::AbstractString, record_type::Type{<:GOME_XXX_1B}, ::Integer)
    return _gome2_raw_record_api_error(record_type)
end
function read_single_record(::MetopDataset, record_type::Type{<:GOME_XXX_1B}, ::Integer)
    return _gome2_raw_record_api_error(record_type)
end

########### Product dispatch ###########
function MetopDatasets.data_record_type(
        header::MainProductHeader, product_type::Val{:GOME_xxx_1B})::Type
    if header.format_major_version == 13
        return GOME_XXX_1B_ROOT_V13
    elseif header.format_major_version == 12
        return GOME_XXX_1B_ROOT_V12
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

# Map a subclass name to the record type reading that subclass. `record_type` is the
# Earthshine type returned by `data_record_type` for this product version.
function MetopDatasets._get_subclass_type(
        record_type::Type{<:GOME_XXX_1B_ROOT}, subclass::Symbol)
    is_v13 = (record_type === GOME_XXX_1B_ROOT_V13)
    if subclass === :earthshine
        return is_v13 ? GOME_XXX_1B_EARTHSHINE_V13 : GOME_XXX_1B_EARTHSHINE_V12
    elseif subclass === :calibration
        return is_v13 ? GOME_XXX_1B_CALIBRATION_V13 : GOME_XXX_1B_CALIBRATION_V12
    elseif subclass === :sun
        return is_v13 ? GOME_XXX_1B_SUN_V13 : GOME_XXX_1B_SUN_V12
    elseif subclass === :moon
        return is_v13 ? GOME_XXX_1B_MOON_V13 : GOME_XXX_1B_MOON_V12
    end
    return error("Unknown subclass `$(subclass)`. Expected one of " *
                 ":earthshine, :calibration, :sun, :moon.")
end

########### Constants ###########
const GOME2_N_SCAN_POSITIONS = 32
const GOME2_N_BANDS = 10
const GOME2_BAND_NAMES = ("1a", "1b", "2a", "2b", "3", "4", "pp", "ps", "swpp", "swps")
const GOME2_MAIN_BAND_RECORD_SIZE = 12
const GOME2_PMD_BAND_RECORD_SIZE_V13 = 16
const GOME2_PMD_BAND_RECORD_SIZE_V12 = 16
const GOME2_GEO_EARTH_ACTUAL_RECORD_SIZE = 99

gome2_main_band_record_size(::Type{<:GOME_XXX_1B}) = GOME2_MAIN_BAND_RECORD_SIZE
function gome2_pmd_band_record_size(::Type{GOME_XXX_1B_EARTHSHINE_V13})
    return GOME2_PMD_BAND_RECORD_SIZE_V13
end
function gome2_pmd_band_record_size(::Type{GOME_XXX_1B_EARTHSHINE_V12})
    return GOME2_PMD_BAND_RECORD_SIZE_V12
end
gome2_pmd_band_record_size(::Type{GOME_XXX_1B_SUN_V13}) = GOME2_PMD_BAND_RECORD_SIZE_V13
gome2_pmd_band_record_size(::Type{GOME_XXX_1B_SUN_V12}) = GOME2_PMD_BAND_RECORD_SIZE_V12
gome2_pmd_band_record_size(::Type{GOME_XXX_1B_MOON_V13}) = GOME2_PMD_BAND_RECORD_SIZE_V13
gome2_pmd_band_record_size(::Type{GOME_XXX_1B_MOON_V12}) = GOME2_PMD_BAND_RECORD_SIZE_V12
function gome2_pmd_band_record_size(::Type{GOME_XXX_1B_CALIBRATION_V13})
    return GOME2_PMD_BAND_RECORD_SIZE_V13
end
function gome2_pmd_band_record_size(::Type{GOME_XXX_1B_CALIBRATION_V12})
    return GOME2_PMD_BAND_RECORD_SIZE_V12
end

has_uncorrected_pmd(::Type{<:GOME_XXX_1B}) = true

function gome2_band_record_sizes(::Type{R}) where {R <: GOME_XXX_1B}
    main_size = gome2_main_band_record_size(R)
    pmd_size = gome2_pmd_band_record_size(R)
    return (
        main_size, main_size, main_size, main_size, main_size, main_size,
        pmd_size, pmd_size, pmd_size, pmd_size)
end

# Earthshine dynamic-section layout (relative to the start of the GEO_EARTH_ACTUAL block).
const GOME2_DYNAMIC_PREFIX_SIZE = 58356
const GOME2_DYNAMIC_REC_LENGTH_REL_OFFSET = 58316
const GOME2_DYNAMIC_NUM_RECS_REL_OFFSET = 58336

const GOME2_GEO_REC_LENGTH_FIELD_SIZE = GOME2_N_BANDS * sizeof(UInt16)  # 10 × 2 = 20

const GOME2_GEO_REC_LENGTH_OFFSET_V13 = 7725
const GOME2_GEO_REC_LENGTH_OFFSET_V12 = 8224

function gome2_geo_rec_length_offset(::Type{GOME_XXX_1B_EARTHSHINE_V13})
    return GOME2_GEO_REC_LENGTH_OFFSET_V13
end
function gome2_geo_rec_length_offset(::Type{GOME_XXX_1B_EARTHSHINE_V12})
    return GOME2_GEO_REC_LENGTH_OFFSET_V12
end

# Non-Earthshine REC_LENGTH and NUM_RECS sit at a constant offset inside the fixed header.
# The offsets are computed from the auto-generated struct so they track the CSV layout
# automatically — no hardcoded byte positions to drift out of sync.

function _gome2_field_offset(T::Type, target::Symbol)
    offset = 0
    for f in fieldnames(T)
        f == target && return offset
        ft = fieldtype(T, f)
        if ft <: AbstractArray
            dims = get_raw_format_dim(T)[f]
            n = prod(d isa Integer ? d : 10 for d in dims)
            offset += n * native_sizeof(eltype(ft))
        else
            offset += native_sizeof(ft)
        end
    end
    return error("Field `$target` not found in $T")
end

gome2_rec_length_offset(T::Type{<:GOME_XXX_1B}) = _gome2_field_offset(T, :rec_length)
gome2_num_recs_offset(T::Type{<:GOME_XXX_1B}) = _gome2_field_offset(T, :num_recs)
function gome2_fixed_header_size(T::Type{<:GOME_XXX_1B})
    return gome2_num_recs_offset(T) + GOME2_GEO_REC_LENGTH_FIELD_SIZE
end
