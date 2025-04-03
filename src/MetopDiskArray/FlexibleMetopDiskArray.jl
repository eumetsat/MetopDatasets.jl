# Copyright (c) 2025 EUMETSAT
# License: MIT

"""
    FlexibleMetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}

Similar to `MetopDiskArray` but able to handle flexible record layout and 
fields where the size varies within a single product file. E.g. IASI L2 fields like "temperature_error".
"""
struct FlexibleMetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}
    file_pointer::IOStream
    record_layout::FlexibleRecordLayout
    field_name::Symbol

    # computed
    field_type::Type
    record_count::Int64
    offsets_in_file::Vector{Int64}
    record_type::Type{<:DataRecord}
end

function FlexibleMetopDiskArray(file_pointer::IOStream,
        record_layouts::Vector{FlexibleRecordLayout},
        field_name::Symbol; auto_convert = true)
    field_type, record_count, offsets_in_file, record_type = layout_info_for_disk_array(
        record_layouts, field_name)
    T, N = _get_T_and_N(field_type, auto_convert)

    return FlexibleMetopDiskArray{T, N}(
        file_pointer,
        only(record_layouts),
        field_name,

        # computed
        field_type,
        record_count,
        offsets_in_file,
        record_type)
end

function Base.size(disk_array::FlexibleMetopDiskArray)
    if disk_array.field_type <: Array
        layout = disk_array.record_layout
        # use max flexible dims for size
        flexible_dims_max = MetopDatasets.get_flex_dim_max(layout)

        field_array_size = _get_array_size_flexible(
            disk_array.record_type, disk_array.field_name,
            layout.flexible_dims_file, flexible_dims_max)

        return (field_array_size..., disk_array.record_count)
    else
        return (disk_array.record_count,)
    end
end

# Extend get index functions
function DiskArrays.readblock!(disk_array::FlexibleMetopDiskArray{T, N},
        aout,
        i::Vararg{OrdinalRange, N}) where {T, N}

    # separate record range.
    i_record = i[end]
    i_array = i[1:(end - 1)]

    offsets_in_file = disk_array.offsets_in_file

    for k in eachindex(i_record)
        record_index = i_record[k]
        field_start_position = offsets_in_file[record_index]
        seek(disk_array.file_pointer, field_start_position)

        aout_rec = selectdim(aout, N, k)

        ## this needs to be updated to account for padding. 
        ## the location variable can also be used for size and so on simplify a alot of the code
        # get size of flex field and read entire field.
        flexible_dims_record = disk_array.record_layout.flexible_dims_records[record_index]
        array_size = _get_array_size_flexible(
            disk_array.record_type, disk_array.field_name,
            disk_array.record_layout.flexible_dims_file, flexible_dims_record)

        full_field = native_read_array(
            disk_array.file_pointer, disk_array.field_type, array_size)

        # get the part of the range overlapping with the actual flex field
        a_range_in_data = _range_with_data(i_array, array_size)
        i_array_in_data = Tuple((i_array[l][a_range_in_data[l]]
        for l in eachindex(i_array)))

        if i_array != i_array_in_data
            # pad the aout_rec with missing values if the range exceeds the 
            # size of the flex field.
            fill_value = get_missing_value(
                disk_array.record_type, disk_array.field_name)
            fill_value = _auto_convert(T, fill_value)
            fill!(aout_rec, fill_value)
        end

        # extract the data in the range that overlap with the flex field
        aout_rec[a_range_in_data...] .= _auto_convert.(
            T, full_field[i_array_in_data...])
    end
    return nothing
end

# helper functions to find data ranges
function _range_with_data(range, max_val)
    first_valid = findfirst(x -> 1 <= x <= max_val, range)
    last_valid = findlast(x -> 1 <= x <= max_val, range)

    if isnothing(first_valid) || isnothing(last_valid)
        # no valid data found. return empty range
        return 1:0
    end

    return first_valid:last_valid
end

function _range_with_data(ranges::Tuple, max_vals::Tuple)
    return Tuple(_range_with_data(ranges[l], max_vals[l]) for l in eachindex(max_vals))
end

# forward method
function fixed_size(disk_array::FlexibleMetopDiskArray)
    return fixed_size(disk_array.record_type, disk_array.field_name)
end

function get_field_dimensions(disk_array::FlexibleMetopDiskArray)
    return get_field_dimensions(
        disk_array.record_type, disk_array.record_layout, disk_array.field_name)
end
