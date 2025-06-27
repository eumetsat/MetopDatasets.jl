# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    MetopVariable{T, N, R <: DataRecord} <: CommonDataModel.AbstractVariable{T, N}

`MetopVariable` wraps an `AbstractArray` so it can be used with `MetopDataset`. 
The data array is normally `AbstractMetopDiskArray`.
"""
struct MetopVariable{T, N, R, A <: AbstractArray{T, N}} <: CDM.AbstractVariable{T, N}
    parent::MetopDataset{R}
    data_array::A
    field_name::Symbol
end

### helper functions to get_cf_attributes.
function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::Dict{Symbol, Any} where {R <: DataRecord}
    return default_cf_attributes(R, field, auto_convert) # logic is factored out for reusability
end

function default_cf_attributes(
        R::Type{<:BinaryRecord}, field::Symbol, auto_convert::Bool)::Dict{Symbol, Any}
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

    missing_value = get_missing_value(R, field)
    if !isnothing(missing_value)
        if auto_convert
            T = _get_convert_type(F)
            missing_value = _auto_convert(T, missing_value)
        end

        cf_attributes[:missing_value] = [missing_value]

        if !fixed_size(R, field)
            cf_attributes[:_FillValue] = missing_value
        end
    end

    return cf_attributes
end

function _get_field_eltype(R::Type{<:BinaryRecord}, field::Symbol)
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
    varname = Symbol(varname)
    disk_array = construct_disk_array(ds.file_pointer, ds.data_record_layouts,
        varname; auto_convert = ds.auto_convert)
    T = eltype(disk_array)
    N = ndims(disk_array)

    return MetopVariable{T, N, R, typeof(disk_array)}(ds, disk_array, varname)
end

function default_dimnames(v::MetopVariable{T, N, R}) where {T, N, R}
    if v.field_name in (:record_start_time, :record_stop_time)
        return [RECORD_DIM_NAME]
    else
        names = get_field_dimensions(R, v.field_name)
        push!(names, RECORD_DIM_NAME)
        return names
    end
end

function Base.getindex(ds::MetopDataset, varname::CDM.SymbolOrString)
    return CDM.cfvariable(ds, varname)
end

function CDM.name(v::MetopVariable)
    return string(v.field_name)
end

CDM.dimnames(v::MetopVariable) = default_dimnames(v)

CDM.dataset(v::MetopVariable) = v.parent

function CDM.attribnames(v::MetopVariable)
    cf_attributes = keys(get_cf_attributes(
        v.parent, v.field_name, v.parent.auto_convert))
    return ("description", string.(cf_attributes)...)
end

function default_attrib(v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {T, N, R}
    if !(string(name) in CDM.attribnames(v))
        error("$name not found")
    end

    if string(name) == "description"
        return get_description(R, v.field_name)
    end

    cf_attributes = get_cf_attributes(
        v.parent, v.field_name, v.parent.auto_convert)
    return cf_attributes[Symbol(name)]
end

function CDM.attrib(v::MetopVariable, name::CDM.SymbolOrString)
    return default_attrib(v, name)
end

Base.size(v::MetopVariable) = size(v.data_array)
Base.parent(v::MetopVariable) = v.data_array

function DiskArrays.readblock!(v::MetopVariable{T, N, R, <:DiskArrays.AbstractArray},
        aout,
        indexes::Vararg{OrdinalRange, N}) where {T, N, R}
    return DiskArrays.readblock!(parent(v), aout, indexes...)
end

function DiskArrays.readblock!(v::MetopVariable{T, N},
        aout,
        indexes::Vararg{OrdinalRange, N}) where {T, N}
    aout .= getindex(parent(v), indexes...)
    return nothing
end

# fix ambiguity
Base.getindex(v::MetopVariable, n::CDM.CFStdName) = getindex(v::CDM.AbstractVariable, n)
function Base.getindex(v::MetopVariable, name::CDM.SymbolOrString)
    return getindex(v::CDM.AbstractVariable, name)
end
