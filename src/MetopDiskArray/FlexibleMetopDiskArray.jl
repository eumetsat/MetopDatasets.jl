# Copyright (c) 2025 EUMETSAT
# License: MIT

"""
    FlexibleMetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}

Similar to `MetopDiskArray` but able to handle flexible record layout and 
fields where the size varies within a single product file. E.g. IASI L2 fields like "temperature_error".
"""
struct FlexibleMetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}
    file_pointer::IOStream
    field_name::Symbol

    # computed
    field_type::Type
    offsets_in_file::Vector{Int64}
    record_type::Type{<:DataRecord}
    size::NTuple{N, Int64}
    flexible_dim::Int64
    data_location::DiskArrays.AbstractDiskArray{Bool}
end

function FlexibleMetopDiskArray(file_pointer::IOStream,
        record_layouts::Vector{FlexibleRecordLayout},
        field_name::Symbol; auto_convert = true)
    field_type, record_count, offsets_in_file, record_type = layout_info_for_disk_array(
        record_layouts, field_name)

    T, N = _get_T_and_N(field_type, auto_convert)

    array_size_raw = _get_array_size(record_type, field_name)
    data_location_dict = flexible_dim_data_location(record_type)

    array_size = zeros(Int64, N - 1)
    local data_location_var::Symbol
    flexible_dim = 0

    for i in eachindex(array_size)
        d = array_size_raw[i]
        if d isa Symbol
            if haskey(data_location_dict, d)
                @assert flexible_dim == 0
                flexible_dim = i
                data_location_var = data_location_dict[d]
                array_size[i] = only(_get_array_size(record_type, data_location_var))
            else
                array_size[i] = only(record_layouts).flexible_dims_file[d]
            end
        else
            array_size[i] = d
        end
    end

    data_location_array = construct_disk_array(
        file_pointer, record_layouts, data_location_var; auto_convert = false)
    data_location = data_location_array .!=
                    get_missing_value(record_type, data_location_var)

    return FlexibleMetopDiskArray{T, N}(
        file_pointer,
        field_name,

        # computed
        field_type,
        offsets_in_file,
        record_type,
        (array_size..., record_count),
        flexible_dim,
        data_location
    )
end

Base.size(disk_array::FlexibleMetopDiskArray) = disk_array.size

# Extend get index functions
function DiskArrays.readblock!(disk_array::FlexibleMetopDiskArray{T, N},
        aout,
        i::Vararg{OrdinalRange, N}) where {T, N}

    # separate record range.
    i_record = i[end]
    i_array = i[1:(end - 1)]

    full_size = disk_array.size[1:(end - 1)]
    flexible_dim = disk_array.flexible_dim
    i_flexible_dim = i_array[flexible_dim]

    offsets_in_file = disk_array.offsets_in_file

    fill_value = get_missing_value(disk_array.record_type, disk_array.field_name)
    fill_value = _auto_convert(T, fill_value)
    fill!(aout, fill_value)

    for k in eachindex(i_record)
        record_index = i_record[k]
        aout_record = selectdim(aout, N, k)

        # Note that accessing the disk_array.data_location will move the file_pointer
        # the file pointer is shared.
        data_location = disk_array.data_location[:, record_index]
        n_size = sum(data_location)
        array_size = (full_size[1:(flexible_dim - 1)]..., n_size,
            full_size[(flexible_dim + 1):end]...)

        field_start_position = offsets_in_file[record_index]

        # Set the file pointer to the correct location right before reading the field 
        seek(disk_array.file_pointer, field_start_position)
        full_field = native_read_array(
            disk_array.file_pointer, disk_array.field_type, array_size)

        # find the index of the selected data in the "full_field"
        position_in_data_field = zeros(Int64, length(data_location))
        position_in_data_field[data_location] .= cumsum(data_location)[data_location]
        data_index = filter!(x -> 0 < x, position_in_data_field[i_flexible_dim])
        i_array_in_data = (i_array[1:(flexible_dim - 1)]..., data_index,
            i_array[(flexible_dim + 1):end]...)

        # view the flexible dimension in the output array
        selected = data_location[i_flexible_dim]
        aout_record_data = selectdim(aout_record, flexible_dim, selected)

        aout_record_data .= _auto_convert.(T, full_field[i_array_in_data...])
    end
    return nothing
end

# forward method
function fixed_size(disk_array::FlexibleMetopDiskArray)
    return fixed_size(disk_array.record_type, disk_array.field_name)
end

function get_field_dimensions(disk_array::FlexibleMetopDiskArray)
    return get_field_dimensions(
        disk_array.record_type, disk_array.record_layout, disk_array.field_name)
end
