# Copyright (c) 2025 EUMETSAT
# License: MIT

# DataElementMetopDiskArray is used to handle the compound types in the HIRS L1B format.
struct DataElementMetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}
    file_pointer::IOStream
    field_name::Symbol
    is_header::Bool

    # computed
    data_element_type::Type
    field_type::Type
    offsets_in_file::Vector{Int64}
    record_type::Type{<:DataRecord}
    dim_size::NTuple{N, Int64}
end

function DataElementMetopDiskArray(file_pointer::IOStream,
        record_layouts::Vector{<:RecordLayout},
        field_name::Symbol, data_element_field_name::Symbol; auto_convert = true)
    data_element_type, record_count,
    offsets_in_file,
    record_type = layout_info_for_disk_array(
        record_layouts, data_element_field_name)

    is_header = field_name in (ELEMENT_RAD_HEADER_NAME, ELEMENT_FLAG_HEADER_NAME)

    field_type = if is_header
        Vector{fieldtypes(eltype(data_element_type))[1]}
    else
        Matrix{eltype(fieldtypes(eltype(data_element_type))[2])}
    end

    T, N = _get_T_and_N(field_type, auto_convert)

    data_element_field_array_size = _get_field_array_size(
        record_layouts, record_type, data_element_field_name)
    dim_size = if is_header
        dim_size = (data_element_field_array_size..., record_count)
    else
        dim_size = (20, data_element_field_array_size..., record_count)
    end

    return DataElementMetopDiskArray{T, N}(
        file_pointer,
        field_name,
        is_header,

        # computed
        data_element_type,
        field_type,
        offsets_in_file,
        record_type,
        dim_size)
end

function _native_read_data_element_header(io::IO, T::Type, byte_to_skip)
    val = native_read(io, T)
    skip(io, byte_to_skip)
    return val
end

function _native_read_data_element_data(io::IO, T::Type)
    skip(io, 4)
    return native_read_array(io, T, (20,))
end

# Extend get index functions
function DiskArrays.readblock!(disk_array::DataElementMetopDiskArray{T, N},
        aout,
        i::Vararg{OrdinalRange, N}) where {T, N}

    # separate record range.
    i_record = i[end]
    i_array = i[1:(end - 1)]

    is_header = disk_array.is_header
    header_field_type = fieldtypes(eltype(disk_array.data_element_type))[1]
    data_field_type = fieldtypes(eltype(disk_array.data_element_type))[2]

    byte_to_skip = is_header ? native_sizeof(data_field_type) :
                   native_sizeof(header_field_type)
    data_element_per_record = is_header ? disk_array.dim_size[1] : disk_array.dim_size[2]

    field_element_type = eltype(disk_array.field_type)

    for k in eachindex(i_record)
        record_index = i_record[k]
        field_start_position = disk_array.offsets_in_file[record_index]
        seek(disk_array.file_pointer, field_start_position)

        full_field = if is_header
            [_native_read_data_element_header(
                 disk_array.file_pointer, field_element_type, byte_to_skip)
             for i in 1:data_element_per_record]
        else
            reduce(hcat,
                _native_read_data_element_data(
                    disk_array.file_pointer, Vector{field_element_type})
                for i in 1:data_element_per_record)
        end

        aout_rec = selectdim(aout, N, k)
        aout_rec .= _auto_convert.(T, full_field[i_array...])
    end
    return nothing
end
