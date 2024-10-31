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
    record_chunks::Vector{RecordChunk}
    field_name::Symbol

    # computed
    field_type::Type
    record_count::Int64
    offset_in_record::Int64
    record_type::Type{<:DataRecord}
    record_offsets::Vector{Int64}
end

"""
    MetopDiskArray(file_pointer::IOStream,
        record_chunks::Vector{RecordChunk},
        field_name::Symbol; auto_convert = true) -> MetopDiskArray

Constructor for MetopDiskArray that compute additional fields. `auto_convert = true` will
automatically convert custom `RecordSubType` to commonly used data types e.g. converting `VInteger` to `Float64`.
"""
function MetopDiskArray(file_pointer::IOStream,
        record_chunks::Vector{RecordChunk},
        field_name::Symbol; auto_convert = true)
    record_chunks = filter(x -> x.record_type != DummyRecord, record_chunks)
    @assert allequal([c.record_type for c in record_chunks])
    record_type = record_chunks[1].record_type

    T = _get_field_eltype(record_type, field_name)
    N = 1
    offset_in_record = 0
    local field_type::Type

    if field_name == :record_start_time
        offset_in_record = 8
        field_type = ShortCdsTime
    elseif field_name == :record_stop_time
        offset_in_record = 14
        field_type = ShortCdsTime
    else
        field_index = findfirst(fieldnames(record_type) .== field_name)
        fields_before = fieldnames(record_type)[1:(field_index - 1)]
        offset_in_record = sum(native_sizeof.(record_type, fields_before))

        field_type = fieldtype(record_type, field_name)
        if field_type <: Array
            N = 1 + ndims(field_type)
        end
    end

    record_count = record_chunks[end].record_range[end]
    record_offsets = _chunks_to_offsets(record_chunks)

    T = auto_convert ? _get_convert_type(T) : T

    return MetopDiskArray{T, N}(file_pointer,
        record_chunks, field_name,
        field_type, record_count,
        offset_in_record,
        record_type,
        record_offsets)
end

function Base.size(disk_array::AbstractMetopDiskArray)
    if disk_array.field_type <: Array
        field_array_size = _get_array_size(disk_array.record_type, disk_array.field_name)
        return (field_array_size..., disk_array.record_count)
    else
        return (disk_array.record_count,)
    end
end

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
        field_start_position = disk_array.record_offsets[record_index] +
                               disk_array.offset_in_record
        seek(disk_array.file_pointer, field_start_position)

        # TODO optimise to not read entire field for Array fields
        full_field = native_read(disk_array.file_pointer, disk_array.record_type,
            disk_array.field_type, disk_array.field_name)

        if N > 1
            aout_rec = selectdim(aout, N, k)
            aout_rec .= _auto_convert.(T, full_field[i_array...])
        else
            aout[k] = _auto_convert(T, full_field)
        end
    end
    return nothing
end

# Set error for write function
function DiskArrays.writeblock!(A::AbstractMetopDiskArray{T, N},
        ain,
        r::Vararg{AbstractUnitRange, N}) where {T, N}
    return error("MetopDiskArray is read-only")
end
