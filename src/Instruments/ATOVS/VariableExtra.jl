
function CDM.varnames(ds::MetopDataset{R}) where {R <: ATOVS_1B}
    if ds.auto_convert
        # replace "data_calibration" with its two components
        public_names = filter(x -> x != string(DATA_CAL_NAME), default_varnames(ds))
        public_names = (public_names...,
            string(DATA_CAL_NEDT_NAME), string(DATA_CAL_QUALITY_NAME))
        return public_names
    end

    return default_varnames(ds)
end

function CDM.variable(ds::MetopDataset{R},
        varname::CDM.SymbolOrString
) where {R <: ATOVS_1B}
    varname = Symbol(varname)

    # handle special conversions
    if ds.auto_convert && (varname == DATA_CAL_NEDT_NAME)
        disk_array = MetopDiskArray(ds.file_pointer, ds.data_record_layouts,
            DATA_CAL_NAME; auto_convert = false)
        disk_array_nedt = get_noise_temperature.(disk_array)
        T = eltype(disk_array_nedt)
        N = ndims(disk_array_nedt)
        return MetopVariable{T, N, R}(ds, disk_array_nedt, varname)
    elseif ds.auto_convert && (varname == DATA_CAL_QUALITY_NAME)
        disk_array = MetopDiskArray(ds.file_pointer, ds.data_record_layouts,
            DATA_CAL_NAME; auto_convert = false)
        disk_array_quality = Base.convert.(UInt8, get_calibration_quality.(disk_array))
        T = eltype(disk_array_quality)
        N = ndims(disk_array_quality)
        return MetopVariable{T, N, R}(ds, disk_array_quality, varname)
    end

    return default_variable(ds, varname)
end

function CDM.attrib(
        v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {
        T, N, R <: ATOVS_1B}
    if (v.field_name == DATA_CAL_QUALITY_NAME) && (string(name) == "description")
        return DATA_CAL_QUALITY_DESCRIPTION
    elseif (v.field_name == DATA_CAL_NEDT_NAME) && (string(name) == "description")
        return DATA_CAL_NEDT_DESCRIPTION
    end

    return default_attrib(v, name)
end

function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::Dict{Symbol, Any} where {R <: ATOVS_1B}
    if (field == DATA_CAL_NEDT_NAME)
        return Dict{Symbol, Any}(
            :units => "K",
            :scale_factor => 10.0^(-2)
        )
    end

    if (field == DATA_CAL_QUALITY_NAME)
        return Dict{Symbol, Any}()
    end

    return default_cf_attributes(R, field, auto_convert)
end
