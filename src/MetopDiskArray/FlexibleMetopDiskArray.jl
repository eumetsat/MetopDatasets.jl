# Copyright (c) 2025 EUMETSAT
# License: MIT

"""
    FlexibleMetopDiskArray{T, N} <: AbstractMetopDiskArray{T, N}

TODO
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

function construct_disk_array(file_pointer::IOStream,
        record_layouts::Vector{FlexibleRecordLayout},
        field_name::Symbol; auto_convert = true)
    return FlexibleMetopDiskArray(file_pointer,
        only(record_layouts),
        field_name::Symbol; auto_convert = auto_convert)
end

function FlexibleMetopDiskArray(file_pointer::IOStream,
        record_layout::FlexibleRecordLayout,
        field_name::Symbol; auto_convert = true)
    record_type = record_layout.record_type

    T = _get_field_eltype(record_type, field_name)
    N = 1
    offsets_in_file = record_layout.offsets
    record_count = length(record_layout.offsets)

    local field_type::Type

    if field_name == :record_start_time
        offsets_in_file = offsets_in_file .+ 8
        field_type = ShortCdsTime
    elseif field_name == :record_stop_time
        offsets_in_file = offsets_in_file .+ 14
        field_type = ShortCdsTime
    else
        field_type = fieldtype(record_type, field_name)
        offset_in_records = _offset_in_record(record_layout, field_name)
        offsets_in_file = offsets_in_file .+ offset_in_records
    end

    if field_type <: Array
        N = 1 + ndims(field_type)
    end

    T = auto_convert ? _get_convert_type(T) : T

    return FlexibleMetopDiskArray{T, N}(
        file_pointer,
        record_layout,
        field_name,

        # computed
        field_type,
        record_count,
        offsets_in_file,
        record_type)
end

function _offset_in_record(record_layout::FlexibleRecordLayout, field_name::Symbol)
    field_index = findfirst(fieldnames(record_layout.record_type) .== field_name)
    size_of_fields_before = record_layout.field_sizes[1:(field_index - 1), :]

    offsets = dropdims(sum(size_of_fields_before, dims = 1), dims = 1)

    return offsets
end

function Base.size(disk_array::FlexibleMetopDiskArray)
    if disk_array.field_type <: Array
        layout = disk_array.record_layout
        flexible_dims_max = MetopDatasets.get_flex_dim_max(layout)

        field_array_size = _get_array_size_flexible(
            disk_array.record_type, disk_array.field_name,
            layout.flexible_dims_file, flexible_dims_max)

        return (field_array_size..., disk_array.record_count)
    else
        return (disk_array.record_count,)
    end
end

function fixed_size(disk_array::FlexibleMetopDiskArray)
    return fixed_size(disk_array.record_type, disk_array.field_name)
end

# Extend get index functions
function DiskArrays.readblock!(disk_array::FlexibleMetopDiskArray{T, N},
        aout,
        i::Vararg{OrdinalRange, N}) where {T, N}

    # separate record range.
    i_record = i[end]
    i_array = i[1:(end - 1)]

    is_field_fixed = fixed_size(disk_array)
    offsets_in_file = disk_array.offsets_in_file

    for k in eachindex(i_record)
        record_index = i_record[k]
        field_start_position = offsets_in_file[record_index]
        seek(disk_array.file_pointer, field_start_position)

        if N > 1 # array field
            aout_rec = selectdim(aout, N, k)

            if is_field_fixed
                array_size = _get_array_size(disk_array.record_type, disk_array.field_name)
                full_field = native_read_array(
                    disk_array.file_pointer, disk_array.field_type, array_size)
                aout_rec .= _auto_convert.(T, full_field[i_array...])
            else
                flexible_dims_record = disk_array.record_layout.flexible_dims_records[record_index]
                array_size = _get_array_size_flexible(
                    disk_array.record_type, disk_array.field_name,
                    disk_array.record_layout.flexible_dims_file, flexible_dims_record)

                a_range_in_data = _range_with_data(i_array, array_size)
                i_array_in_data = Tuple((i_array[l][a_range_in_data[l]]
                for l in eachindex(i_array)))

                full_field = native_read_array(
                    disk_array.file_pointer, disk_array.field_type, array_size)

                if i_array != i_array_in_data
                    # pre fill with missing values
                    fill_value = get_missing_value(
                        disk_array.record_type, disk_array.field_name)
                    fill_value = _auto_convert(T, fill_value)
                    fill!(aout_rec, fill_value)
                end

                aout_rec[a_range_in_data...] .= _auto_convert.(
                    T, full_field[i_array_in_data...])
            end
        else # Scalar field 
            scalar_value = native_read(disk_array.file_pointer, disk_array.field_type)
            aout[k] = _auto_convert(T, scalar_value)
        end
    end
    return nothing
end

function _range_with_data(range, max_val)
    first_valid = findfirst(x -> 1 <= x <= max_val, range)
    last_valid = findlast(x -> 1 <= x <= max_val, range)

    return first_valid:last_valid
end

function _range_with_data(ranges::Tuple, max_vals::Tuple)
    return Tuple(_range_with_data(ranges[l], max_vals[l]) for l in eachindex(max_vals))
end

function get_field_dimensions(disk_array::FlexibleMetopDiskArray)
    return get_field_dimensions(
        disk_array.record_type, disk_array.record_layout, disk_array.field_name)
end
