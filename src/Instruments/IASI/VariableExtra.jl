# Copyright (c) 2024 EUMETSAT
# License: MIT

function CDM.varnames(ds::MetopDataset{R}) where {R <: IASI_XXX_1C}
    if ds.auto_convert
        public_names = (string(IASI_WAVENUMBER_NAME), default_varnames(ds)...)
        return public_names
    end

    return default_varnames(ds)
end

# Overload to enable special scaling for IASI spectrum.
function CDM.variable(
        ds::MetopDataset{R}, varname::CDM.SymbolOrString) where {R <: IASI_XXX_1C}
    varname = Symbol(varname)

    if ds.auto_convert && varname in (:gs1cspect, IASI_WAVENUMBER_NAME)
        disk_array = if varname == :gs1cspect
            sepctrum_disk_array = IasiSpectrumDiskArray(
                ds.file_pointer, ds.data_record_layouts,
                varname; high_precision = ds.high_precision)
            sepctrum_disk_array
        elseif varname == IASI_WAVENUMBER_NAME
            wavenumber_disk_array = IasiWaveNumberDiskArray(ds, varname)
            wavenumber_disk_array
        end

        T = eltype(disk_array)
        N = ndims(disk_array)
        return MetopVariable{T, N, R, typeof(disk_array)}(ds, disk_array, varname)
    else
        return default_variable(ds, varname)
    end
end

# Overload to add :gircimage scale_factor from giadr. Not given in the format specs like the rest.
function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::Dict{Symbol, Any} where {R <: IASI_XXX_1C}
    if field == IASI_WAVENUMBER_NAME
        return Dict{Symbol, Any}(
            :units => "m-1"
        )
    end

    cf_attributes = default_cf_attributes(R, field, auto_convert)

    if field == :gircimage
        giadr = read_first_record(ds, GIADR_IASI_XXX_1C_V11)
        scale_factor = giadr.idefscaleiisscalefactor
        cf_attributes[:scale_factor] = 10.0^(-scale_factor)
    end

    return cf_attributes
end

function CDM.attrib(
        v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {T, N, R <: IASI_XXX_1C}
    if (v.field_name == IASI_WAVENUMBER_NAME) && (string(name) == "description")
        return IASI_WAVENUMBER_DESCRIPTION
    end

    return default_attrib(v, name)
end

function CDM.dimnames(v::MetopVariable{T, N, R}) where {T, N, R <: IASI_XXX_1C}
    if v.field_name == IASI_WAVENUMBER_NAME
        spectrum_dim = get_field_dimensions(R, :gs1cspect)[1]
        return [spectrum_dim, RECORD_DIM_NAME]
    end

    return default_dimnames(v)
end

########### Level 2 ###############

function CDM.varnames(ds::MetopDataset{R}) where {R <: IASI_SND_02}
    normal_varnames = default_varnames(ds)
    gaird_type = _get_giard_type(R)
    giard_varnames = string.(get_giard_varnames(gaird_type))

    if R <: IASI_SND_02_V10
        return (normal_varnames..., giard_varnames..., IASI_L2_V10_ERROR_DATA_NAME)
    end

    return (normal_varnames..., giard_varnames...)
end

function CDM.variable(
        ds::MetopDataset{R}, varname::CDM.SymbolOrString) where {R <: IASI_SND_02}
    varname = Symbol(varname)

    if R <: IASI_SND_02_V10 && varname == IASI_L2_V10_ERROR_DATA_NAME
        layout = only(ds.data_record_layouts)
        error_field_offset = sum(layout.field_sizes, dims = 1)[:]
        error_field_size = layout.record_sizes .- error_field_offset
        data_array = LazyByteField(ds.file_pointer, error_field_offset, error_field_size)
        return MetopVariable{Vector{UInt8}, 1, R, typeof(data_array)}(
            ds, data_array, varname)
    end

    gaird_type = _get_giard_type(R)
    giard_varnames = get_giard_varnames(gaird_type)

    if varname in giard_varnames
        gaird = read_first_record(ds, gaird_type)
        data_array = getfield(gaird, varname)
        T = eltype(data_array)
        N = ndims(data_array)
        return MetopVariable{T, N, R, typeof(data_array)}(ds, data_array, varname)
    end

    return default_variable(ds, varname)
end

function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::Dict{Symbol, Any} where {R <: IASI_SND_02}
    if (field == IASI_L2_V10_ERROR_DATA_NAME)
        return Dict{Symbol, Any}()
    end

    gaird_type = _get_giard_type(R)
    giard_varnames = get_giard_varnames(gaird_type)

    if field in giard_varnames
        return default_cf_attributes(gaird_type, field, auto_convert)
    else
        return default_cf_attributes(R, field, auto_convert)
    end
end

function CDM.attrib(
        v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {T, N, R <: IASI_SND_02}
    if (v.field_name == IASI_L2_V10_ERROR_DATA_NAME) && (string(name) == "description")
        return IASI_L2_V10_ERROR_DATA_DESCRIPTION
    end

    gaird_type = _get_giard_type(R)
    giard_varnames = get_giard_varnames(gaird_type)

    if (v.field_name in giard_varnames) && (string(name) == "description")
        return get_description(gaird_type, v.field_name)
    end

    return default_attrib(v, name)
end

function CDM.dimnames(v::MetopVariable{T, N, R}) where {T, N, R <: IASI_SND_02}
    if (v.field_name == IASI_L2_V10_ERROR_DATA_NAME)
        return [RECORD_DIM_NAME]
    end

    gaird_type = _get_giard_type(R)
    giard_varnames = get_giard_varnames(gaird_type)

    if v.field_name in giard_varnames
        names = get_field_dimensions(gaird_type, v.field_name)
        return names
    end

    return default_dimnames(v)
end

function Base.getindex(ds::MetopDataset{IASI_SND_02_V10}, varname::CDM.SymbolOrString)
    if Symbol(varname) == IASI_L2_V10_ERROR_DATA_NAME
        ## Use cfvariable does not work with byte array 
        return CDM.variable(ds, varname)
    end
    return CDM.cfvariable(ds, varname)
end
