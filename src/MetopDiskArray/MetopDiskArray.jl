# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    AbstractMetopDiskArray{T, N} <: DiskArrays.AbstractDiskArray{T, N}

In most cases `MetopDiskArray` is used but `AbstractMetopDiskArray` allows defining additional
DiskArray types to handle special corner cases. 
"""
abstract type AbstractMetopDiskArray{T, N} <: DiskArrays.AbstractDiskArray{T, N} end

"""
    MetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}

Struct to handle  lazy loading of a variable in a Metop product. The raw types in the product is mapped without any 
scaling. Auto conversion can be enabled for `RecordSubType` e.g. converting `VInteger` to `Float64`.
"""
struct MetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}
    file_pointer::IOStream
    field_name::Symbol

    # computed
    field_type::Type
    offsets_in_file::Vector{Int64}
    record_type::Type{<:DataRecord}
    size::NTuple{N, Int64}
end

"""
    MetopDiskArray(file_pointer::IOStream,
        record_layouts::Vector{FixedRecordLayout},
        field_name::Symbol; auto_convert = true) -> MetopDiskArray

Constructor for MetopDiskArray that compute additional fields. `auto_convert = true` will
automatically convert custom `RecordSubType` to commonly used data types e.g. converting `VInteger` to `Float64`.
"""
function MetopDiskArray(file_pointer::IOStream,
        record_layouts::Vector{<:RecordLayout},
        field_name::Symbol; auto_convert = true)
    field_type, record_count, offsets_in_file, record_type = layout_info_for_disk_array(
        record_layouts, field_name)
    T, N = _get_T_and_N(field_type, auto_convert)

    local dim_size::NTuple{N, Int64}
    if field_type <: AbstractArray
        field_array_size = _get_field_array_size(record_layouts, record_type, field_name)
        size = (field_array_size..., record_count)
    else
        size = (record_count,)
    end

    return MetopDiskArray{T, N}(
        file_pointer,
        field_name,

        # computed
        field_type,
        offsets_in_file,
        record_type,
        size)
end

Base.size(disk_array::AbstractMetopDiskArray) = disk_array.size

# Define chunk structure
DiskArrays.haschunks(::AbstractMetopDiskArray) = DiskArrays.Chunked();

function DiskArrays.eachchunk(disk_array::AbstractMetopDiskArray)
    # the chunk is equivalent to reading the variable from a single record.
    return DiskArrays.GridChunks(disk_array, (size(disk_array)[1:(end - 1)]..., 1))
end;

# Extend get index functions
function DiskArrays.readblock!(disk_array::MetopDiskArray{T, N},
        aout,
        i::Vararg{OrdinalRange, N}) where {T, N}

    # separate record range.
    i_record = i[end]
    i_array = i[1:(end - 1)]

    for k in eachindex(i_record)
        record_index = i_record[k]
        field_start_position = disk_array.offsets_in_file[record_index]
        seek(disk_array.file_pointer, field_start_position)

        if N > 1
            # TODO optimise to not read entire field for Array fields
            field_array_size = disk_array.size[1:(end - 1)]
            full_field = native_read_array(
                disk_array.file_pointer, disk_array.field_type, field_array_size)
            aout_rec = selectdim(aout, N, k)
            aout_rec .= _auto_convert.(T, full_field[i_array...])
        else
            full_field = native_read(disk_array.file_pointer, disk_array.field_type)
            aout[k] = _auto_convert(T, full_field)
        end
    end
    return nothing
end

# helper function
function get_field_dimensions(disk_array::AbstractMetopDiskArray)
    return get_field_dimensions(disk_array.record_type, disk_array.field_name)
end

# Set error for write function
function DiskArrays.writeblock!(A::AbstractMetopDiskArray{T, N},
        ain,
        r::Vararg{AbstractUnitRange, N}) where {T, N}
    return error("MetopDiskArray is read-only")
end
