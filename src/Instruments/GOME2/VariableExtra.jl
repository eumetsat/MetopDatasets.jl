# Copyright (c) 2024 EUMETSAT
# License: MIT

# --- Variable name generation ---

function _gome2_spectral_varnames(::Type{R}) where {R <: GOME_XXX_1B}
    names = Symbol[]
    for (i, bname) in enumerate(GOME2_BAND_NAMES)
        push!(names, Symbol("wavelength_$bname"))
        push!(names, Symbol("radiance_$bname"))
        push!(names, Symbol("radiance_error_$bname"))
        if i <= 6  # main bands
            push!(names, Symbol("stokes_fraction_$bname"))
        elseif has_uncorrected_pmd(R)  # PMD bands with uncorrected components
            push!(names, Symbol("uncorrected_radiance_$bname"))
            push!(names, Symbol("uncorrected_radiance_error_$bname"))
        end
        push!(names, Symbol("rec_length_$bname"))
        push!(names, Symbol("num_recs_$bname"))
    end
    return names
end

function _gome2_spectral_varnames_all()
    names = Symbol[]
    append!(names, _gome2_spectral_varnames(GOME_XXX_1B_V13))
    append!(names, _gome2_spectral_varnames(GOME_XXX_1B_V12))
    return unique(names)
end

function _gome2_extra_varnames(::Type{R}) where {R <: GOME_XXX_1B}
    return (
        :latitude, :longitude, _gome2_spectral_varnames(R)...)
end

const GOME2_SPECTRAL_VARNAMES = _gome2_spectral_varnames_all()
const GOME2_EXTRA_VARNAMES = (:latitude, :longitude, GOME2_SPECTRAL_VARNAMES...)
const GOME2_GEO_PAIR_FIELDS = (
    :centre, :corner, :scan_centre, :scan_corner, :sub_satellite_point)
const GOME2_FLOAT_SPECTRAL_COMPONENTS = (
    :wavelength, :radiance, :radiance_error, :stokes_fraction,
    :uncorrected_radiance, :uncorrected_radiance_error)
const GOME2_OUTPUT_SELECTION_COMPONENTS = (
    :radiance, :radiance_error, :uncorrected_radiance, :uncorrected_radiance_error)
const GOME2_OUTPUT_SELECTION_UNITS = Dict{Symbol, String}(
    :abs_rad => "photon s-1 cm-2 nm-1 sr-1",
    :norm_rad => "1")

function _is_gome2_extra_var(varname::Symbol)
    return varname in GOME2_EXTRA_VARNAMES
end

# --- CDM.varnames ---

function CDM.varnames(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    base_names = default_varnames(ds)
    extra_symbols = ds.auto_convert ? _gome2_extra_varnames(R) : (:latitude, :longitude)
    extra_names = string.(extra_symbols)
    return (extra_names..., base_names...)
end

# --- Spectral info caching ---
const GOME2_SPECTRAL_CACHE_KEY = :gome2_spectral_info
const GOME2_OUTPUT_SELECTION_CACHE_KEY = :gome2_output_selection_info

function _get_spectral_info(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    info = get!(ds.cache, GOME2_SPECTRAL_CACHE_KEY) do
        return compute_spectral_info(
            ds.file_pointer, ds.data_record_layouts, R)
    end
    return info::GomeSpectralInfo
end

function _get_output_selection_info(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    output_selection_info = get!(ds.cache, GOME2_OUTPUT_SELECTION_CACHE_KEY) do
        output_selection_da = construct_disk_array(
            ds.file_pointer, ds.data_record_layouts, :output_selection; auto_convert = false)
        values = collect(output_selection_da[1:ds.data_record_count])

        fill_value = get_missing_value(R, :output_selection)
        if !isnothing(fill_value)
            filter!(x -> x != fill_value, values)
        end

        unique_values = sort(unique(values))
        mode = if isempty(unique_values)
            :unknown
        elseif length(unique_values) == 1
            if unique_values[1] == 0x00
                :abs_rad
            elseif unique_values[1] == 0x01
                :norm_rad
            else
                :unknown
            end
        else
            :mixed
        end

        return (mode, unique_values)
    end
    return output_selection_info::Tuple{Symbol, Vector{UInt8}}
end

# --- Parse spectral variable name ---

function _parse_spectral_varname(varname::Symbol)
    s = string(varname)

    for (i, bname) in enumerate(GOME2_BAND_NAMES)
        if s == "wavelength_$bname"
            return (i, :wavelength, bname)
        elseif s == "radiance_$bname"
            return (i, :radiance, bname)
        elseif s == "radiance_error_$bname"
            return (i, :radiance_error, bname)
        elseif s == "stokes_fraction_$bname"
            return (i, :stokes_fraction, bname)
        elseif s == "uncorrected_radiance_$bname"
            return (i, :uncorrected_radiance, bname)
        elseif s == "uncorrected_radiance_error_$bname"
            return (i, :uncorrected_radiance_error, bname)
        elseif s == "rec_length_$bname"
            return (i, :rec_length, bname)
        elseif s == "num_recs_$bname"
            return (i, :num_recs, bname)
        end
    end
    return nothing
end

function _is_supported_spectral_component(
        ::Type{R}, band_index::Int, component::Symbol) where {R <: GOME_XXX_1B}
    if component == :stokes_fraction
        return band_index <= 6
    elseif component in (:uncorrected_radiance, :uncorrected_radiance_error)
        return band_index >= 7 && has_uncorrected_pmd(R)
    end
    return true
end

# --- CDM.variable ---

function CDM.variable(
        ds::MetopDataset{R}, varname::CDM.SymbolOrString) where {R <: GOME_XXX_1B}
    varname = Symbol(varname)

    if !_is_gome2_extra_var(varname)
        return default_variable(ds, varname)
    end

    if varname == :latitude
        disk_array = _gome2_latlon_disk_array(ds, :latitude)
        return MetopVariable{Float64, 2, R, typeof(disk_array)}(ds, disk_array, varname)
    elseif varname == :longitude
        disk_array = _gome2_latlon_disk_array(ds, :longitude)
        return MetopVariable{Float64, 2, R, typeof(disk_array)}(ds, disk_array, varname)
    end

    parsed = _parse_spectral_varname(varname)
    if isnothing(parsed)
        return default_variable(ds, varname)
    end
    if !ds.auto_convert
        return default_variable(ds, varname)
    end

    band_index, component, _ = parsed
    if !_is_supported_spectral_component(R, band_index, component)
        return default_variable(ds, varname)
    end
    spectral_info = _get_spectral_info(ds)

    disk_array = if component == :wavelength
        GomeWavelengthDiskArray(
            ds.file_pointer, spectral_info, R, band_index, varname)
    elseif component in (:rec_length, :num_recs)
        GomeLayoutDiskArray(spectral_info, band_index, component, varname)
    else
        GomeRadianceDiskArray(
            ds.file_pointer, spectral_info, R, band_index, component, varname)
    end

    T = eltype(disk_array)
    N = ndims(disk_array)
    return MetopVariable{T, N, R, typeof(disk_array)}(ds, disk_array, varname)
end

# --- Latitude/Longitude extraction ---

# CRITICAL: lat/lon component order differs between v5 and v6
# v6 (V13): CENTRE field is [lon, lat] — lat_component=1, lon_component=0 (0-indexed)
# v5 (V12): CENTRE field is [lat, lon] — lat_component=0, lon_component=1 (0-indexed)

_lat_index(::Type{GOME_XXX_1B_V13}) = 2  # 1-indexed: second component
_lon_index(::Type{GOME_XXX_1B_V13}) = 1  # 1-indexed: first component
_lat_index(::Type{GOME_XXX_1B_V12}) = 1  # 1-indexed: first component
_lon_index(::Type{GOME_XXX_1B_V12}) = 2  # 1-indexed: second component

_geo_component_order(::Type{GOME_XXX_1B_V13}) = "longitude, latitude"
_geo_component_order(::Type{GOME_XXX_1B_V12}) = "latitude, longitude"

function _output_selection_mode_attribute(mode::Symbol)
    if mode == :abs_rad
        return "0"
    elseif mode == :norm_rad
        return "1"
    elseif mode == :mixed
        return "mixed"
    end
    return "unknown"
end

function _output_selection_values_attribute(values::Vector{UInt8})
    if isempty(values)
        return ""
    end
    return join(Int.(values), ",")
end

function _output_selection_comment(mode::Symbol, values::Vector{UInt8})
    if mode == :abs_rad
        return "OUTPUT_SELECTION=0 (AbsRad): calibrated radiance mode."
    elseif mode == :norm_rad
        return "OUTPUT_SELECTION=1 (NormRad): sun-normalized radiance mode."
    elseif mode == :mixed
        return "Mixed OUTPUT_SELECTION values ($(join(Int.(values), ", "))) across records."
    end
    return "Unknown OUTPUT_SELECTION values ($(join(Int.(values), ", ")))."
end

function _spectral_units(component::Symbol, mode::Symbol)
    if component == :wavelength
        return "nm"
    elseif component in (:stokes_fraction, :rec_length, :num_recs)
        return "1"
    elseif component in GOME2_OUTPUT_SELECTION_COMPONENTS
        return get(GOME2_OUTPUT_SELECTION_UNITS, mode, nothing)
    end
    return nothing
end

function _gome2_geo_pair_description(::Type{R}, field::Symbol) where {R <: GOME_XXX_1B}
    order = _geo_component_order(R)
    if field == :centre
        return "Geodetic coordinates at ground point F (geo_component order: $order)"
    elseif field == :corner
        return "Geodetic coordinates at ground points A, B, C, D (geo_component order: $order)"
    elseif field == :scan_centre
        return "Geodetic coordinates at scan centre (geo_component order: $order)"
    elseif field == :scan_corner
        return "Geodetic coordinates for scan corner points A, B, C, D (geo_component order: $order)"
    elseif field == :sub_satellite_point
        return "Geodetic coordinates of sub-satellite point (geo_component order: $order)"
    end
    return get_description(R, field)
end

"""
    GomeLatLonDiskArray <: AbstractMetopDiskArray{Float64, 2}

Extracts latitude or longitude from the CENTRE field (32×2 Int32, SF=6).
Shape: `(32, n_records)`.
"""
struct GomeLatLonDiskArray <: AbstractMetopDiskArray{Float64, 2}
    centre_disk_array::MetopDiskArray
    component_index::Int  # 1 or 2 — which component of the 2-element geo pair
    field_name::Symbol
    dim_size::Tuple{Int64, Int64}
end

function _gome2_latlon_disk_array(ds::MetopDataset{R}, which::Symbol) where {R <:
                                                                             GOME_XXX_1B}
    centre_da = construct_disk_array(
        ds.file_pointer, ds.data_record_layouts, :centre; auto_convert = false)
    comp_idx = which == :latitude ? _lat_index(R) : _lon_index(R)
    n_records = ds.data_record_count
    return GomeLatLonDiskArray(centre_da, comp_idx, which, (Int64(32), Int64(n_records)))
end

Base.size(da::GomeLatLonDiskArray) = da.dim_size

@inline function _decode_centre_component(raw_centre::AbstractMatrix{<:Integer},
        scan_index::Int, component_index::Int)
    # Binary payload stores 32 pairs as [comp1_scan1, comp2_scan1, comp1_scan2, ...].
    # Generic array reshape in MetopDiskArray is column-major, so values are interleaved
    # within each 32-element column. Decode by reconstructing the original pair index.
    half_scans = Int(GOME2_N_SCAN_POSITIONS ÷ 2)
    local_scan = scan_index <= half_scans ? scan_index : (scan_index - half_scans)
    col = scan_index <= half_scans ? 1 : 2
    row = 2 * local_scan - (component_index == 1 ? 1 : 0)
    return raw_centre[row, col]
end

function DiskArrays.readblock!(
        disk_array::GomeLatLonDiskArray, aout,
        i_scan::OrdinalRange, i_record::OrdinalRange)
    raw = disk_array.centre_disk_array[:, :, i_record]
    for (k, rec_idx) in enumerate(i_record)
        raw_centre = @view raw[:, :, k]
        for (j, scan_idx) in enumerate(i_scan)
            val = _decode_centre_component(raw_centre, scan_idx, disk_array.component_index)
            if val == typemin(Int32)
                aout[j, k] = NaN
            else
                aout[j, k] = val * 1e-6
            end
        end
    end
    return nothing
end

# --- Dataset dimension overrides ---

# Include spectral dimensions in the dataset's dimension list by computing them from
# the spectral info. This requires reading the file to determine max spectral sizes.
function get_dimensions(::Type{<:GOME_XXX_1B},
        data_record_layouts::Vector{<:RecordLayout})::OrderedDict{String, <:Integer}
    # Start with fixed dimensions from the fixed-header fields
    dims = OrderedDict{String, Integer}(
        "geo_component" => 2,
        "efg" => 3,
        "corner" => 4,
        "band" => 10,
        "stokes_band" => 15,
        "scan_position" => 32,
        "scanner" => 65,
        "pmd_readout" => 256
    )
    return dims
end

# Override CDM.dimnames and CDM.dim to include spectral dimensions dynamically
function CDM.dimnames(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    base_names = collect(keys(get_dimensions(ds)))
    push!(base_names, RECORD_DIM_NAME)

    if ds.auto_convert
        # Add spectral dimension names without forcing a full MDR spectral scan.
        for bname in GOME2_BAND_NAMES
            push!(base_names, "wavelength_$bname")
            push!(base_names, "readout_$bname")
        end
    end

    return base_names
end

function _parse_spectral_dim_name(name::AbstractString)
    for (i, bname) in enumerate(GOME2_BAND_NAMES)
        if name == "wavelength_$bname"
            return (i, :wavelength)
        elseif name == "readout_$bname"
            return (i, :readout)
        end
    end
    return nothing
end

function CDM.dim(ds::MetopDataset{R}, name::CDM.SymbolOrString) where {R <: GOME_XXX_1B}
    name = string(name)
    if RECORD_DIM_NAME == name
        return ds.data_record_count
    end

    spectral_dim = _parse_spectral_dim_name(name)
    if ds.auto_convert && !isnothing(spectral_dim)
        i, kind = spectral_dim
        spectral_info = _get_spectral_info(ds)
        if kind == :wavelength
            return Int(spectral_info.max_rec_lengths[i])
        end
        return Int(spectral_info.max_num_recs[i])
    end

    return get_dimensions(ds)[name]
end

# --- CDM.dimnames for variables ---

function CDM.dimnames(v::MetopVariable{T, N, R}) where {T, N, R <: GOME_XXX_1B}
    if v.field_name in (:latitude, :longitude)
        return ["scan_position", RECORD_DIM_NAME]
    end

    parsed = _parse_spectral_varname(v.field_name)
    if !isnothing(parsed)
        _, component, bname = parsed
        if component == :wavelength
            return ["wavelength_$bname", RECORD_DIM_NAME]
        elseif component in (:rec_length, :num_recs)
            return [RECORD_DIM_NAME]
        else
            return ["wavelength_$bname", "readout_$bname", RECORD_DIM_NAME]
        end
    end

    return default_dimnames(v)
end

# --- CDM.attrib ---

function CDM.attrib(
        v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {T, N, R <: GOME_XXX_1B}
    if string(name) == "description"
        if _is_gome2_extra_var(v.field_name)
            return _gome2_extra_description(v.parent, v.field_name)
        elseif v.field_name in GOME2_GEO_PAIR_FIELDS
            return _gome2_geo_pair_description(R, v.field_name)
        end
    end

    return default_attrib(v, name)
end

function _gome2_extra_description(ds::MetopDataset{R}, field::Symbol) where {R <:
                                                                             GOME_XXX_1B}
    if field == :latitude
        return "Latitude extracted from CENTRE field (-90 to 90 deg)"
    elseif field == :longitude
        return "Longitude extracted from CENTRE field"
    end

    parsed = _parse_spectral_varname(field)
    if !isnothing(parsed)
        _, component, bname = parsed
        mode, values = _get_output_selection_info(ds)
        if component == :wavelength
            return "Wavelength for band $bname (nm)"
        elseif component == :radiance
            if mode == :abs_rad
                return "Calibrated radiance for band $bname"
            elseif mode == :norm_rad
                return "Sun-normalized radiance for band $bname"
            elseif mode == :mixed
                return "Radiance for band $bname (mixed OUTPUT_SELECTION values: $(join(Int.(values), ", ")))"
            end
            return "Radiance for band $bname (unknown OUTPUT_SELECTION mode)"
        elseif component == :radiance_error
            if mode == :abs_rad
                return "Calibrated radiance error for band $bname"
            elseif mode == :norm_rad
                return "Sun-normalized radiance error for band $bname"
            elseif mode == :mixed
                return "Radiance error for band $bname (mixed OUTPUT_SELECTION values: $(join(Int.(values), ", ")))"
            end
            return "Radiance error for band $bname (unknown OUTPUT_SELECTION mode)"
        elseif component == :stokes_fraction
            return "Stokes fraction for band $bname"
        elseif component == :uncorrected_radiance
            if mode == :abs_rad
                return "Uncorrected calibrated radiance for band $bname"
            elseif mode == :norm_rad
                return "Uncorrected sun-normalized radiance for band $bname"
            elseif mode == :mixed
                return "Uncorrected radiance for band $bname (mixed OUTPUT_SELECTION values: $(join(Int.(values), ", ")))"
            end
            return "Uncorrected radiance for band $bname (unknown OUTPUT_SELECTION mode)"
        elseif component == :uncorrected_radiance_error
            if mode == :abs_rad
                return "Uncorrected calibrated radiance error for band $bname"
            elseif mode == :norm_rad
                return "Uncorrected sun-normalized radiance error for band $bname"
            elseif mode == :mixed
                return "Uncorrected radiance error for band $bname (mixed OUTPUT_SELECTION values: $(join(Int.(values), ", ")))"
            end
            return "Uncorrected radiance error for band $bname (unknown OUTPUT_SELECTION mode)"
        elseif component == :rec_length
            return "Number of spectral elements per record for band $bname"
        elseif component == :num_recs
            return "Number of readout records per scan for band $bname"
        end
    end

    return ""
end

# --- get_cf_attributes ---

function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::AbstractDict{Symbol, Any} where {R <: GOME_XXX_1B}
    if field == :latitude
        return Dict{Symbol, Any}(
            :units => "degrees_north",
            :missing_value => NaN,
            :_FillValue => NaN)
    elseif field == :longitude
        return Dict{Symbol, Any}(
            :units => "degrees_east",
            :missing_value => NaN,
            :_FillValue => NaN)
    end

    parsed = _parse_spectral_varname(field)
    if !isnothing(parsed)
        _, component, _ = parsed
        mode, values = _get_output_selection_info(ds)
        attrs = Dict{Symbol, Any}()

        units = _spectral_units(component, mode)
        if !isnothing(units)
            attrs[:units] = units
        end

        if component in GOME2_FLOAT_SPECTRAL_COMPONENTS
            attrs[:missing_value] = NaN
            attrs[:_FillValue] = NaN
        end

        attrs[:output_selection_mode] = _output_selection_mode_attribute(mode)
        attrs[:output_selection_values] = _output_selection_values_attribute(values)
        attrs[:comment] = _output_selection_comment(mode, values)
        return attrs
    elseif field in GOME2_GEO_PAIR_FIELDS
        cf_attributes = Dict{Symbol, Any}(default_cf_attributes(R, field, auto_convert))
        cf_attributes[:geo_component_order] = _geo_component_order(R)
        return cf_attributes
    end

    return default_cf_attributes(R, field, auto_convert)
end
