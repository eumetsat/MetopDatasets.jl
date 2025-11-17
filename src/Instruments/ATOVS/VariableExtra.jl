# Copyright (c) 2025 EUMETSAT
# License: MIT

function _replace_var_name!(var_names, remove_name, insert_names)
    if !(remove_name in var_names)
        return var_names
    end

    i = findfirst(isequal(remove_name), var_names)
    deleteat!(var_names, i)
    for n in reverse(insert_names)
        insert!(var_names, i, n)
    end

    return var_names
end

function CDM.varnames(ds::MetopDataset{R}) where {R <: ATOVS_1B}
    if ds.auto_convert
        # replace "data_calibration" with its two components
        public_names = [default_varnames(ds)...]
        _replace_var_name!(public_names, string(DATA_CAL_NAME),
            [string(DATA_CAL_NEDT_NAME), string(DATA_CAL_QUALITY_NAME)])
        _replace_var_name!(public_names, string(ELEMENT_RAD_NAME),
            [string(ELEMENT_RAD_DATA_NAME), string(ELEMENT_RAD_HEADER_NAME)])
        _replace_var_name!(public_names, string(ELEMENT_FLAG_NAME),
            [string(ELEMENT_FLAG_DATA_NAME), string(ELEMENT_FLAG_HEADER_NAME)])
        return tuple(public_names...)
    end

    return default_varnames(ds)
end

function CDM.variable(ds::MetopDataset{R},
        varname::CDM.SymbolOrString
) where {R <: ATOVS_1B}
    varname = Symbol(varname)

    # handle special conversions
    if ds.auto_convert && (varname in EXTRACTED_VARS)
        local disk_array

        if (varname == DATA_CAL_NEDT_NAME) && ds.auto_convert
            disk_array_raw = MetopDiskArray(ds.file_pointer, ds.data_record_layouts,
                DATA_CAL_NAME; auto_convert = false)
            disk_array = get_noise_temperature.(disk_array_raw)

        elseif (varname == DATA_CAL_QUALITY_NAME) && ds.auto_convert
            disk_array_raw = MetopDiskArray(ds.file_pointer, ds.data_record_layouts,
                DATA_CAL_NAME; auto_convert = false)
            disk_array = Base.convert.(UInt8, get_calibration_quality.(disk_array_raw))

        else
            data_element_field_name = if varname in (
                ELEMENT_RAD_HEADER_NAME, ELEMENT_RAD_DATA_NAME)
                ELEMENT_RAD_NAME
            else
                ELEMENT_FLAG_NAME
            end

            disk_array = DataElementMetopDiskArray(ds.file_pointer, ds.data_record_layouts,
                varname, data_element_field_name; auto_convert = ds.auto_convert)
        end

        T = eltype(disk_array)
        N = ndims(disk_array)
        return MetopVariable{T, N, R, typeof(disk_array)}(ds, disk_array, varname)
    end

    return default_variable(ds, varname)
end

function CDM.attrib(
        v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {
        T, N, R <: ATOVS_1B}
    if (string(name) == "description") && (v.field_name in EXTRACTED_VARS)
        if v.field_name == DATA_CAL_QUALITY_NAME
            return DATA_CAL_QUALITY_DESCRIPTION
        elseif v.field_name == DATA_CAL_NEDT_NAME
            return DATA_CAL_NEDT_DESCRIPTION
        elseif v.field_name == ELEMENT_RAD_DATA_NAME
            return get_description(R, ELEMENT_RAD_NAME)
        elseif v.field_name == ELEMENT_RAD_HEADER_NAME
            return "Headers for $ELEMENT_RAD_NAME"
        elseif v.field_name == ELEMENT_FLAG_DATA_NAME
            return get_description(R, ELEMENT_FLAG_NAME)
        elseif v.field_name == ELEMENT_FLAG_HEADER_NAME
            return "Headers for $ELEMENT_FLAG_NAME"
        end
    end

    return default_attrib(v, name)
end

function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::AbstractDict{Symbol, Any} where {R <: ATOVS_1B}
    if (field == DATA_CAL_NEDT_NAME)
        return Dict{Symbol, Any}(
            :units => "K",
            :scale_factor => 10.0^(-2),
            :missing_value => get_missing_value(R, UInt8, field)
        )
    elseif field == ELEMENT_RAD_DATA_NAME
        return Dict{Symbol, Any}(
            :scale_factor => 10.0^(-7),
            :missing_value => get_missing_value(R, Int32, field)
        )
    end

    if (field in EXTRACTED_VARS)
        return Dict{Symbol, Any}()
    end

    return default_cf_attributes(R, field, auto_convert)
end
