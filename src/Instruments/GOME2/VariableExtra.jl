# Copyright (c) 2024 EUMETSAT
# License: MIT

# --- Variable name generation ---

function _gome2_spectral_varnames()
    names = Symbol[]
    for (i, bname) in enumerate(GOME2_BAND_NAMES)
        push!(names, Symbol("wavelength_$bname"))
        push!(names, Symbol("radiance_$bname"))
        push!(names, Symbol("radiance_error_$bname"))
        if i <= 6  # main bands
            push!(names, Symbol("stokes_fraction_$bname"))
        else  # PMD bands
            push!(names, Symbol("uncorrected_radiance_$bname"))
            push!(names, Symbol("uncorrected_radiance_error_$bname"))
        end
        push!(names, Symbol("rec_length_$bname"))
        push!(names, Symbol("num_recs_$bname"))
    end
    return names
end

const GOME2_SPECTRAL_VARNAMES = _gome2_spectral_varnames()
const GOME2_EXTRA_VARNAMES = (:latitude, :longitude, GOME2_SPECTRAL_VARNAMES...)

function _is_gome2_extra_var(varname::Symbol)
    return varname in GOME2_EXTRA_VARNAMES
end

# --- CDM.varnames ---

function CDM.varnames(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    base_names = default_varnames(ds)
    extra_names = string.(GOME2_EXTRA_VARNAMES)
    return (extra_names..., base_names...)
end

# --- Spectral info caching ---
const _GOME2_SPECTRAL_CACHE = Dict{UInt64, GomeSpectralInfo}()

function _get_spectral_info(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    key = objectid(ds.file_pointer)
    if !haskey(_GOME2_SPECTRAL_CACHE, key)
        _GOME2_SPECTRAL_CACHE[key] = compute_spectral_info(
            ds.file_pointer, ds.data_record_layouts, R)
    end
    return _GOME2_SPECTRAL_CACHE[key]
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

    band_index, component, _ = parsed
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

function DiskArrays.readblock!(
        disk_array::GomeLatLonDiskArray, aout,
        i_scan::OrdinalRange, i_record::OrdinalRange)
    raw = disk_array.centre_disk_array[i_scan, disk_array.component_index:disk_array.component_index, i_record]
    aout .= dropdims(raw, dims = 2) .* 1e-6  # SF=6
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

    # Add spectral dimension names
    spectral_info = _get_spectral_info(ds)
    for bname in GOME2_BAND_NAMES
        push!(base_names, "wavelength_$bname")
        push!(base_names, "readout_$bname")
    end

    return base_names
end

function CDM.dim(ds::MetopDataset{R}, name::CDM.SymbolOrString) where {R <: GOME_XXX_1B}
    name = string(name)
    if RECORD_DIM_NAME == name
        return ds.data_record_count
    end

    # Check spectral dimensions
    spectral_info = _get_spectral_info(ds)
    for (i, bname) in enumerate(GOME2_BAND_NAMES)
        if name == "wavelength_$bname"
            return Int(spectral_info.max_rec_lengths[i])
        elseif name == "readout_$bname"
            return Int(spectral_info.max_num_recs[i])
        end
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
    if string(name) == "description" && _is_gome2_extra_var(v.field_name)
        return _gome2_extra_description(v.field_name)
    end

    return default_attrib(v, name)
end

function _gome2_extra_description(field::Symbol)
    if field == :latitude
        return "Latitude extracted from CENTRE field (-90 to 90 deg)"
    elseif field == :longitude
        return "Longitude extracted from CENTRE field"
    end

    parsed = _parse_spectral_varname(field)
    if !isnothing(parsed)
        _, component, bname = parsed
        if component == :wavelength
            return "Wavelength for band $bname (nm)"
        elseif component == :radiance
            return "Calibrated radiance for band $bname"
        elseif component == :radiance_error
            return "Radiance error for band $bname"
        elseif component == :stokes_fraction
            return "Stokes fraction for band $bname"
        elseif component == :uncorrected_radiance
            return "Uncorrected radiance for band $bname"
        elseif component == :uncorrected_radiance_error
            return "Uncorrected radiance error for band $bname"
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
        return Dict{Symbol, Any}(:units => "degrees_north")
    elseif field == :longitude
        return Dict{Symbol, Any}(:units => "degrees_east")
    end

    parsed = _parse_spectral_varname(field)
    if !isnothing(parsed)
        _, component, _ = parsed
        if component == :wavelength
            return Dict{Symbol, Any}(:units => "nm")
        else
            return Dict{Symbol, Any}()
        end
    end

    return default_cf_attributes(R, field, auto_convert)
end
