# Copyright (c) 2024 EUMETSAT
# License: MIT


function _gome2_spectral_varnames(R::Type{<:GOME_XXX_1B})
    names = Symbol[]
    for (i, bname) in enumerate(GOME2_BAND_NAMES)
        push!(names, Symbol("wavelength_$bname"))
        push!(names, Symbol("radiance_$bname"))
        push!(names, Symbol("radiance_error_$bname"))
        if i <= 6  # main bands
            push!(names, Symbol("stokes_fraction_$bname"))
        elseif has_uncorrected_pmd(R)
            push!(names, Symbol("uncorrected_radiance_$bname"))
            push!(names, Symbol("uncorrected_radiance_error_$bname"))
        end
        push!(names, Symbol("rec_length_$bname"))
        push!(names, Symbol("num_recs_$bname"))
    end
    return names
end

const GOME2_SPECTRAL_VARNAMES = begin
    names = Symbol[]
    append!(names, _gome2_spectral_varnames(GOME_XXX_1B_V13))
    append!(names, _gome2_spectral_varnames(GOME_XXX_1B_V12))
    unique(names)
end

# latitude / longitude are synthesised from CENTRE; only Earthshine has that field.
const GOME2_EARTHSHINE_EXTRA_VARNAMES = (:latitude, :longitude)

_gome2_has_centre_field(::Type) = false
_gome2_has_centre_field(::Type{<:GOME_XXX_1B_V13}) = true
_gome2_has_centre_field(::Type{<:GOME_XXX_1B_V12}) = true

function _gome2_extra_varnames(R::Type{<:GOME_XXX_1B})
    extras = Symbol[]
    if _gome2_has_centre_field(R)
        append!(extras, GOME2_EARTHSHINE_EXTRA_VARNAMES)
    end
    append!(extras, _gome2_spectral_varnames(R))
    return Tuple(extras)
end

const GOME2_EXTRA_VARNAMES = (:latitude, :longitude, GOME2_SPECTRAL_VARNAMES...)
const GOME2_GEO_PAIR_FIELDS = (
    :centre, :corner, :scan_centre, :scan_corner, :sub_satellite_point)
const GOME2_FLOAT_SPECTRAL_COMPONENTS = (
    :radiance, :radiance_error, :stokes_fraction,
    :uncorrected_radiance, :uncorrected_radiance_error)
const GOME2_OUTPUT_SELECTION_COMPONENTS = (
    :radiance, :radiance_error, :uncorrected_radiance, :uncorrected_radiance_error)
const GOME2_OUTPUT_SELECTION_UNITS = Dict{Symbol, String}(
    :abs_rad           => "photon s-1 cm-2 nm-1 sr-1",   # Earthshine, OUTPUT_SELECTION=0
    :norm_rad          => "1",                            # Earthshine, OUTPUT_SELECTION=1
    :solar_irradiance  => "photon s-1 cm-2 nm-1",         # Sun MDR
    :lunar_radiance    => "photon s-1 cm-2 nm-1 sr-1",    # Moon MDR
    # Calibration MDR: BAND_* compound carries the same calibrated units as
    # Earthshine, but the physical meaning per record depends on the
    # internal source (Dark/LED/WLS/SLS/SLS_diffuser) — see OBSERVATION_MODE.
    :calibration_signal        => "photon s-1 cm-2 nm-1 sr-1",
    :calibration_dark          => "photon s-1 cm-2 nm-1 sr-1",
    :calibration_LED           => "photon s-1 cm-2 nm-1 sr-1",
    :calibration_WLS           => "photon s-1 cm-2 nm-1 sr-1",
    :calibration_SLS           => "photon s-1 cm-2 nm-1 sr-1",
    :calibration_SLS_diffuser  => "photon s-1 cm-2 nm-1 sr-1",
    :calibration_mixed         => "photon s-1 cm-2 nm-1 sr-1",
)

# Measurement mode for non-Earthshine MDRs (no OUTPUT_SELECTION field).
_gome2_default_mode(::Type{<:GOME_XXX_1B}) = :unknown
_gome2_default_mode(::Type{<:GOME_XXX_1B_SUN_V13}) = :solar_irradiance
_gome2_default_mode(::Type{<:GOME_XXX_1B_SUN_V12}) = :solar_irradiance
_gome2_default_mode(::Type{<:GOME_XXX_1B_MOON_V13}) = :lunar_radiance
_gome2_default_mode(::Type{<:GOME_XXX_1B_MOON_V12}) = :lunar_radiance
_gome2_default_mode(::Type{<:GOME_XXX_1B_CALIBRATION_V13}) = :calibration_signal
_gome2_default_mode(::Type{<:GOME_XXX_1B_CALIBRATION_V12}) = :calibration_signal

function _is_gome2_extra_var(varname::Symbol)
    return varname in GOME2_EXTRA_VARNAMES
end


function CDM.varnames(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    base_names = default_varnames(ds)
    if ds.auto_convert
        extra_symbols = _gome2_extra_varnames(R)
    else
        # Without auto_convert, only the synthesised lat/lon are exposed.
        extra_symbols = _gome2_has_centre_field(R) ?
                        GOME2_EARTHSHINE_EXTRA_VARNAMES : ()
    end
    extra_names = string.(extra_symbols)
    return (extra_names..., base_names...)
end

const GOME2_SPECTRAL_CACHE_KEY = :gome2_spectral_info
const GOME2_OUTPUT_SELECTION_CACHE_KEY = :gome2_output_selection_info
const GOME2_OBSERVATION_MODE_CACHE_KEY = :gome2_observation_mode_info

# OBSERVATION_MODE enumeration from the GOME-2 PFS, restricted to the values
# that can appear in a non-Earthshine MDR (Calibration / Sun / Moon).
const GOME2_OBSERVATION_MODE_LABELS = Dict{UInt8, String}(
    0x06 => "dark",
    0x07 => "LED",
    0x08 => "WLS",
    0x09 => "SLS",
    0x0a => "SLS_diffuser",
    0x0b => "sun",
    0x0c => "moon",
)

# Cache OBSERVATION_MODE values present in this dataset (one sorted UInt8 vector).
function _get_observation_mode_values(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    return get!(ds.cache, GOME2_OBSERVATION_MODE_CACHE_KEY) do
        da = construct_disk_array(
            ds.file_pointer, ds.data_record_layouts, :observation_mode; auto_convert = false)
        values = collect(da[1:ds.data_record_count])
        fill_value = get_missing_value(R, :observation_mode)
        isnothing(fill_value) || filter!(x -> x != fill_value, values)
        return sort(unique(values))::Vector{UInt8}
    end
end

# Map the set of OBSERVATION_MODE values to a refined mode symbol for the
# Calibration subclass (per-record modes Dark/LED/WLS/SLS/SLS_diffuser).
function _gome2_calibration_mode(values::Vector{UInt8})
    isempty(values) && return :calibration_signal
    length(values) == 1 || return :calibration_mixed
    v = values[1]
    v == 0x06 && return :calibration_dark
    v == 0x07 && return :calibration_LED
    v == 0x08 && return :calibration_WLS
    v == 0x09 && return :calibration_SLS
    v == 0x0a && return :calibration_SLS_diffuser
    return :calibration_signal
end

function _get_spectral_info(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    info = get!(ds.cache, GOME2_SPECTRAL_CACHE_KEY) do
        return compute_spectral_info(
            ds.file_pointer, ds.data_record_layouts, R)
    end
    return info::GomeSpectralInfo
end

function _get_output_selection_info(ds::MetopDataset{R}) where {R <: GOME_XXX_1B}
    # OUTPUT_SELECTION exists only in Earthshine. For Sun/Moon, mode is fixed
    # by subclass identity. For Calibration, OBSERVATION_MODE distinguishes
    # Dark/LED/WLS/SLS/SLS_diffuser per record — surface the actual modes.
    if !hasfield(R, :output_selection)
        if R <: Union{GOME_XXX_1B_CALIBRATION_V13, GOME_XXX_1B_CALIBRATION_V12}
            obs_modes = _get_observation_mode_values(ds)
            return (_gome2_calibration_mode(obs_modes), obs_modes)
        end
        return (_gome2_default_mode(R), UInt8[])::Tuple{Symbol, Vector{UInt8}}
    end
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


function CDM.variable(
        ds::MetopDataset{R}, varname::CDM.SymbolOrString) where {R <: GOME_XXX_1B}
    varname = Symbol(varname)

    if !_is_gome2_extra_var(varname)
        return default_variable(ds, varname)
    end

    if varname in (:latitude, :longitude)
        if !_gome2_has_centre_field(R)
            error("Variable `$varname` is only defined for Earthshine MDRs " *
                  "(record type $R has no CENTRE field).")
        end
        disk_array = _gome2_latlon_disk_array(ds, varname)
        return MetopVariable(ds, disk_array, varname)
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


# Both V13 and V12 store CENTRE as [latitude, longitude], matching the
# descriptor CSV and CODA library specification.
_lat_index(::Type{<:GOME_XXX_1B}) = 1  # 1-indexed: first component
_lon_index(::Type{<:GOME_XXX_1B}) = 2  # 1-indexed: second component

_geo_component_order(::Type{<:GOME_XXX_1B}) = "latitude, longitude"

function _output_selection_mode_attribute(mode::Symbol)
    if mode == :abs_rad
        return "0"
    elseif mode == :norm_rad
        return "1"
    elseif mode == :mixed
        return "mixed"
    elseif mode in (:solar_irradiance, :lunar_radiance,
                    :calibration_signal, :calibration_dark, :calibration_LED,
                    :calibration_WLS, :calibration_SLS, :calibration_SLS_diffuser,
                    :calibration_mixed)
        return string(mode)
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
    elseif mode == :solar_irradiance
        return "MDR-1b-Sun: calibrated solar irradiance (no OUTPUT_SELECTION field)."
    elseif mode == :lunar_radiance
        return "MDR-1b-Moon: calibrated lunar radiance (no OUTPUT_SELECTION field)."
    elseif mode in (:calibration_dark, :calibration_LED, :calibration_WLS,
                    :calibration_SLS, :calibration_SLS_diffuser)
        m = match(r"^calibration_(.+)$", string(mode))
        return "MDR-1b-Calibration: $(m.captures[1]) measurement."
    elseif mode == :calibration_mixed
        present = filter(v -> haskey(GOME2_OBSERVATION_MODE_LABELS, v), values)
        labels = join((GOME2_OBSERVATION_MODE_LABELS[v] for v in present), ", ")
        return "MDR-1b-Calibration: mixed internal-source modes across records ($labels)."
    elseif mode == :calibration_signal
        return "MDR-1b-Calibration: calibrated internal-source signal."
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
    GomeLatLonDiskArray <: AbstractMetopDiskArray{Int32, 2}

Extracts latitude or longitude from the CENTRE field (32×2 Int32, SF=6).
Shape: `(32, n_records)`.
"""
struct GomeLatLonDiskArray <: AbstractMetopDiskArray{Int32, 2}
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
            aout[j, k] = val
        end
    end
    return nothing
end


# Keep the fixed GOME-2 dimensions in GOME2_dimensions.jl and add the spectral
# dimensions lazily here so dataset metadata stays aligned with the record definitions.
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
            elseif mode == :solar_irradiance
                return "Calibrated solar irradiance for band $bname (Sun MDR)"
            elseif mode == :lunar_radiance
                return "Calibrated lunar radiance for band $bname (Moon MDR)"
            elseif mode == :calibration_signal
                return "Calibrated calibration-mode signal for band $bname (Calibration MDR)"
            elseif mode in (:calibration_dark, :calibration_LED, :calibration_WLS,
                            :calibration_SLS, :calibration_SLS_diffuser)
                m = match(r"^calibration_(.+)$", string(mode))
                return "Calibration-mode signal ($(m.captures[1])) for band $bname (Calibration MDR)"
            elseif mode == :calibration_mixed
                return "Calibration-mode signal (mixed internal sources) for band $bname (Calibration MDR)"
            elseif mode == :mixed
                return "Radiance for band $bname (mixed OUTPUT_SELECTION values: $(join(Int.(values), ", ")))"
            end
            return "Radiance for band $bname (unknown OUTPUT_SELECTION mode)"
        elseif component == :radiance_error
            if mode == :abs_rad
                return "Calibrated radiance error for band $bname"
            elseif mode == :norm_rad
                return "Sun-normalized radiance error for band $bname"
            elseif mode == :solar_irradiance
                return "Calibrated solar irradiance error for band $bname (Sun MDR)"
            elseif mode == :lunar_radiance
                return "Calibrated lunar radiance error for band $bname (Moon MDR)"
            elseif mode == :calibration_signal
                return "Calibration-mode signal error for band $bname (Calibration MDR)"
            elseif mode in (:calibration_dark, :calibration_LED, :calibration_WLS,
                            :calibration_SLS, :calibration_SLS_diffuser, :calibration_mixed)
                return "Calibration-mode signal error for band $bname (Calibration MDR)"
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


function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::AbstractDict{Symbol, Any} where {R <: GOME_XXX_1B}
    if field == :latitude
        return Dict{Symbol, Any}(
            :units => "degrees_north",
            :missing_value => typemin(Int32),
            :scale_factor => 1e-6,
            )
    elseif field == :longitude
        return Dict{Symbol, Any}(
            :units => "degrees_east",
            :missing_value => typemin(Int32),
            :scale_factor => 1e-6,)
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

        if component == :wavelength
            attrs[:scale_factor] = 1e-6
            attrs[:missing_value] = GOME2_INT32_FILL_VALUE
            attrs[:_FillValue] = GOME2_INT32_FILL_VALUE
        elseif component in GOME2_FLOAT_SPECTRAL_COMPONENTS
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
