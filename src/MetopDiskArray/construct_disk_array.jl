# Copyright (c) 2025 EUMETSAT
# License: MIT

"""
    construct_disk_array(file_pointer::IOStream,
        record_layouts::Vector{<:RecordLayout},
        field_name::Symbol; auto_convert = true)

Construct a disk array. The type of disk array is automatically determined. The standard type
of disk array is `MetopDiskArray` but there are also other types. `FlexibleMetopDiskArray` is 
returned for fields where the size varies inside the product, eg. IASI L2 "temperature_error".
"""
function construct_disk_array(file_pointer::IOStream,
        record_layouts::Vector{<:RecordLayout},
        field_name::Symbol; auto_convert = true)
    record_layouts = filter(x -> x.record_type != DummyRecord, record_layouts)
    @assert allequal([c.record_type for c in record_layouts])

    # field_fixed_in_file is used to determine if a 
    # normal MetopDiskArray is constructed or a FlexibleMetopDiskArray
    field_fixed_in_file = fixed_size_in_file(
        first(record_layouts).record_type, field_name)

    return construct_disk_array(
        Val(field_fixed_in_file),
        file_pointer,
        record_layouts,
        field_name; auto_convert = auto_convert)
end

function construct_disk_array(
        fixed_size_field_in_file::Val{true},
        file_pointer::IOStream,
        record_layouts::Vector{<:RecordLayout},
        field_name::Symbol; auto_convert = true)
    return MetopDiskArray(file_pointer,
        record_layouts,
        field_name; auto_convert = auto_convert)
end

function construct_disk_array(
        fixed_size_field_in_file::Val{false},
        file_pointer::IOStream,
        record_layouts::Vector{FlexibleRecordLayout},
        field_name::Symbol; auto_convert = true)
    return FlexibleMetopDiskArray(file_pointer,
        record_layouts,
        field_name; auto_convert = auto_convert)
end

## helper functions ##
function _get_T_and_N(field_type::Type, auto_convert::Bool)
    T = field_type
    N = 1

    if field_type <: Array
        N = 1 + ndims(field_type)
        T = eltype(T)
    end

    T = auto_convert ? _get_convert_type(T) : T
    return T, N
end
