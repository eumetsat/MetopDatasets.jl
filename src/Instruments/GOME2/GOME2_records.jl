# Copyright (c) 2024 EUMETSAT
# License: MIT

# CSV format specifications for GOME-2 L1B fixed-header fields
const GOME_xxx_1B_V13_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_V13.csv")
const GOME_xxx_1B_V12_format = @path joinpath(@__DIR__, "csv_formats/GOME_xxx_1B_V12.csv")

abstract type GOME_XXX_1B <: DataRecord end

# Auto-generate record structs from CSV
eval(record_struct_expression(GOME_xxx_1B_V13_format, GOME_XXX_1B))
eval(record_struct_expression(GOME_xxx_1B_V12_format, GOME_XXX_1B))

# N_GEO_BANDS is a symbolic dimension in the CSV (for geo_rec_length field) so that
# fixed_size() automatically returns false. We provide it as a file-level flexible dim
# with a constant value of 10. This makes the FlexibleRecordLayout path scan records
# individually (needed because MDR records are variable-size in the file).
function MetopDatasets._get_flexible_dims_file(::IO, ::Type{<:GOME_XXX_1B})
    return OrderedDict{Symbol, Int64}(:N_GEO_BANDS => 10)
end

MetopDatasets.get_flexible_dim_fields(::Type{<:GOME_XXX_1B}) = OrderedDict{Symbol, Symbol}()

# Filter only MDR-1b-Earthshine records (subclass=6). Other subclasses (7=Sun, etc.)
# have different binary layouts and must not be included.
MetopDatasets.get_instrument_subclass(::Type{<:GOME_XXX_1B}) = 6

function _gome2_raw_record_api_error(record_type::Type{<:GOME_XXX_1B})
    msg = "Raw-record API is disabled for $record_type. "
    msg *= "GOME-2 MDR structs generated from CSV only model fixed-header fields "
    msg *= "through GEO_REC_LENGTH and do not include the full spectral payload. "
    msg *= "Use MetopDataset variables (e.g. ds[\"radiance_1a\"]) instead."
    return error(msg)
end

function read_single_record(
        ::IO, record_type::Type{<:GOME_XXX_1B}, ::Integer)
    return _gome2_raw_record_api_error(record_type)
end

function read_single_record(
        ::AbstractString, record_type::Type{<:GOME_XXX_1B}, ::Integer)
    return _gome2_raw_record_api_error(record_type)
end

function read_single_record(
        ::MetopDataset, record_type::Type{<:GOME_XXX_1B}, ::Integer)
    return _gome2_raw_record_api_error(record_type)
end

# Product dispatch — both NRT and FDR R3 share product name prefix "GOME_xxx_1B"
function MetopDatasets.data_record_type(
        header::MainProductHeader, ::Val{Symbol("GOME_xxx_1B")})::Type
    if header.format_major_version == 13
        return GOME_XXX_1B_V13
    elseif header.format_major_version == 12
        return GOME_XXX_1B_V12
    else
        error("Unsupported GOME-2 format_major_version: $(header.format_major_version)")
    end
end

# Constants
const GOME2_N_SCAN_POSITIONS = 32
const GOME2_N_BANDS = 10
const GOME2_BAND_NAMES = ("1a", "1b", "2a", "2b", "3", "4", "pp", "ps", "swpp", "swps")
const GOME2_MAIN_BAND_RECORD_SIZE = 12
const GOME2_PMD_BAND_RECORD_SIZE_V13 = 16
const GOME2_PMD_BAND_RECORD_SIZE_V12 = 16
const GOME2_GEO_EARTH_ACTUAL_RECORD_SIZE = 99

gome2_main_band_record_size(::Type{<:GOME_XXX_1B}) = GOME2_MAIN_BAND_RECORD_SIZE
gome2_pmd_band_record_size(::Type{GOME_XXX_1B_V13}) = GOME2_PMD_BAND_RECORD_SIZE_V13
gome2_pmd_band_record_size(::Type{GOME_XXX_1B_V12}) = GOME2_PMD_BAND_RECORD_SIZE_V12

has_uncorrected_pmd(::Type{GOME_XXX_1B_V13}) = true
has_uncorrected_pmd(::Type{GOME_XXX_1B_V12}) = true

function gome2_band_record_sizes(::Type{R}) where {R <: GOME_XXX_1B}
    main_size = gome2_main_band_record_size(R)
    pmd_size = gome2_pmd_band_record_size(R)
    return (
        main_size, main_size, main_size, main_size, main_size, main_size,
        pmd_size, pmd_size, pmd_size, pmd_size)
end

# Dynamic section layout constants (fixed across all records)
const GOME2_DYNAMIC_PREFIX_SIZE = 58356
const GOME2_DYNAMIC_REC_LENGTH_REL_OFFSET = 58316  # 58356 - 40
const GOME2_DYNAMIC_NUM_RECS_REL_OFFSET = 58336    # 58356 - 20

# Version-specific GEO_REC_LENGTH offset within MDR
const GOME2_GEO_REC_LENGTH_OFFSET_V13 = 7725
const GOME2_GEO_REC_LENGTH_OFFSET_V12 = 8224

gome2_geo_rec_length_offset(::Type{GOME_XXX_1B_V13}) = GOME2_GEO_REC_LENGTH_OFFSET_V13
gome2_geo_rec_length_offset(::Type{GOME_XXX_1B_V12}) = GOME2_GEO_REC_LENGTH_OFFSET_V12
