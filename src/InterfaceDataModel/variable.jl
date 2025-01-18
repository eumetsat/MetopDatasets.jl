# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    MetopVariable{T, N, R <: DataRecord} <: CommonDataModel.AbstractVariable{T, N}

`MetopVariable` wraps `AbstractMetopDiskArray` so it can be used with `MetopDataset`.
"""
struct MetopVariable{T, N, R} <: CDM.AbstractVariable{T, N}
    parent::MetopDataset{R}
    disk_array::AbstractMetopDiskArray{T, N}
end

### helper functions to get_cf_attributes.
function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::Dict{Symbol, Any} where {R <: DataRecord}
    return default_cf_attributes(R, field, auto_convert) # logic is factored out for reusability
end

function default_cf_attributes(
        R::Type{<:DataRecord}, field::Symbol, auto_convert::Bool)::Dict{Symbol, Any}
    cf_attributes = Dict{Symbol, Any}()

    F = _get_field_eltype(R, field)
    if F <: CdsTime
        if auto_convert
            # units only works for CdsTime types that have been converted to real numbers. 
            cf_attributes[:units] = "seconds since " * format(EPOCH_TIME, "yyyy-m-d H:M:S")
        end
        return cf_attributes
    end

    scale_factor = get_scale_factor(R, field)
    if !isnothing(scale_factor)
        if scale_factor != 0
            cf_attributes[:scale_factor] = 10.0^(-scale_factor)
        end
    end

    if !fixed_size(R, field)
        fill_value = get_missing_value(R, field)

        if auto_convert
            T = _get_convert_type(F)
            fill_value = _auto_convert(T, fill_value)
        end
        cf_attributes[:fillvalue] = fill_value
    end
    #TODO consider adding _FillValue or missing_value, units, 
    return cf_attributes
end

function _get_field_eltype(R::Type{<:DataRecord}, field::Symbol)
    if (field == :record_start_time) || (field == :record_stop_time)
        return ShortCdsTime
    end

    F = fieldtype(R, field)
    if F <: AbstractArray
        F = eltype(F)
    end
    return F
end

## Extend CommonDataModel.AbstractVariable interface
function CDM.variable(ds::MetopDataset, varname::CDM.SymbolOrString)
    return default_variable(ds, varname) # logic is factored out for reusability
end

function default_variable(ds::MetopDataset{R}, varname::CDM.SymbolOrString) where {R}
    disk_array = construct_disk_array(ds.file_pointer, ds.data_record_layouts,
        Symbol(varname); auto_convert = ds.auto_convert)
    T = eltype(disk_array)
    N = ndims(disk_array)
    return MetopVariable{T, N, R}(ds, disk_array)
end

function Base.getindex(ds::MetopDataset, varname::CDM.SymbolOrString)
    cf_attributes = get_cf_attributes(ds, Symbol(varname), ds.auto_convert)

    return CDM.cfvariable(ds, varname; cf_attributes...)
end

function CDM.name(v::MetopVariable)
    return string(v.disk_array.field_name)
end

CDM.dimnames(v::MetopVariable) = CDM.dimnames(v.disk_array)

function CDM.dimnames(disk_array::AbstractMetopDiskArray{T, N}) where {T, N}
    if (disk_array.field_name == :record_start_time) ||
       (disk_array.field_name == :record_stop_time)
        return [RECORD_DIM_NAME]
    end

    dims = get_field_dimensions(disk_array)
    push!(dims, RECORD_DIM_NAME)
    return dims
end

CDM.dataset(v::MetopVariable) = v.parent

function CDM.attribnames(v::MetopVariable)
    cf_attributes = keys(get_cf_attributes(
        v.parent, v.disk_array.field_name, v.parent.auto_convert))
    return ("description", string.(cf_attributes)...)
end

function default_attrib(v::MetopVariable, name::CDM.SymbolOrString)
    if !(string(name) in CDM.attribnames(v))
        error("$name not found")
    end

    if string(name) == "description"
        return get_description(v.disk_array.record_type, v.disk_array.field_name)
    end

    cf_attributes = get_cf_attributes(
        v.parent, v.disk_array.field_name, v.parent.auto_convert)
    return cf_attributes[Symbol(name)]
end

function CDM.attrib(v::MetopVariable, name::CDM.SymbolOrString)
    return default_attrib(v, name)
end

Base.size(v::MetopVariable) = size(v.disk_array)

### get index 
function Base.getindex(v::MetopVariable, indices...)
    checkbounds(v, indices...)
    return getindex(v.disk_array, indices...)
end
# fix ambiguity
Base.getindex(v::MetopVariable, n::CDM.CFStdName) = getindex(v::CDM.AbstractVariable, n)
function Base.getindex(v::MetopVariable, name::CDM.SymbolOrString)
    return getindex(v::CDM.AbstractVariable, name)
end
