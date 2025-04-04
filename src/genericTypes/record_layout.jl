# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    read_record_layouts(file_pointer::IO, main_product_header::MainProductHeader)

Read the appropriate record layout from IO.
"""
function read_record_layouts(file_pointer::IO, main_product_header::MainProductHeader)
    record_type = data_record_type(main_product_header)
    return read_record_layouts(
        file_pointer, main_product_header, Val(fixed_size(record_type)))
end

"""
    layout_info_for_disk_array(record_layouts::Vector{<:RecordLayout}, field_name::Symbol)

Extract information need in `MetopDiskArray`
"""
function layout_info_for_disk_array(
        record_layouts::Vector{<:RecordLayout}, field_name::Symbol)
    record_type = first(record_layouts).record_type
    offsets_in_file = _layouts_to_offsets(record_layouts)
    record_count = length(offsets_in_file)

    local field_type::Type
    if field_name == :record_start_time
        offsets_in_file .+= 8
        field_type = ShortCdsTime
    elseif field_name == :record_stop_time
        offsets_in_file .+= 14
        field_type = ShortCdsTime
    else
        offset_in_record = _get_offset_in_record(
            record_type, field_name, first(record_layouts))
        offsets_in_file .+= offset_in_record
        field_type = fieldtype(record_type, field_name)
    end

    return field_type, record_count, offsets_in_file, record_type
end

"""
    FixedRecordLayout

Used to store the record layout of fixed size data records in a Native metop files.
"""
struct FixedRecordLayout <: RecordLayout
    record_range::UnitRange{Int64}
    offset::Int64
    record_type::Type{<:Record}
end

function read_record_layouts(file_pointer::IO, main_product_header::MainProductHeader,
        fixed_size::Val{true})::Vector{FixedRecordLayout}
    record_type = data_record_type(main_product_header)

    # read internal pointer records
    internal_pointer_records = Vector{InternalPointerRecord}(undef,
        main_product_header.total_ipr)
    for i in eachindex(internal_pointer_records)
        internal_pointer_records[i] = native_read(file_pointer, InternalPointerRecord)
    end

    # get record layouts
    total_file_size = main_product_header.actual_product_size

    record_layouts = _get_data_record_layouts(internal_pointer_records,
        total_file_size,
        record_type)

    return record_layouts
end

"""
    _get_data_record_layouts(internal_pointer_records::Vector{InternalPointerRecord},
        total_file_size::Integer, record_type::Type{<:DataRecord})::Vector{FixedRecordLayout}

Compute the `record_layouts`
"""
function _get_data_record_layouts(internal_pointer_records::Vector{InternalPointerRecord},
        total_file_size::Integer, record_type::Type{<:DataRecord})::Vector{FixedRecordLayout}
    record_layouts = FixedRecordLayout[]

    for i in eachindex(internal_pointer_records)
        pointer = internal_pointer_records[i]
        if pointer.record_class != get_record_class(DataRecord) # not a data record type
            continue
        end

        offset = Int64(pointer.record_offset)
        byte_end = i == length(internal_pointer_records) ? total_file_size :
                   Int64(internal_pointer_records[i + 1].record_offset)
        byte_size = byte_end - offset
        record_type_i = pointer.instrument_group == get_instrument_group(DummyRecord) ?
                        DummyRecord : record_type
        _add_record_layout!(record_layouts, offset, byte_size, record_type_i)
    end

    return record_layouts
end

function _add_record_layout!(record_layouts, offset, byte_size, record_type_i)
    record_size = native_sizeof(record_type_i)
    number_of_record = Int64(byte_size / record_size)
    layout_of_type = filter(x -> x.record_type == record_type_i, record_layouts)

    index_start = isempty(layout_of_type) ? 1 : layout_of_type[end].record_range[end] + 1
    index_end = index_start - 1 + number_of_record
    push!(record_layouts, FixedRecordLayout(index_start:index_end, offset, record_type_i))
    return nothing
end

function _layouts_to_offsets(record_layouts::Vector{FixedRecordLayout})::Vector{<:Integer}
    record_size = native_sizeof(record_layouts[1].record_type)
    record_offsets = [record_size .* (c.record_range .- c.record_range[1]) .+ c.offset
                      for c in record_layouts]
    return vcat(record_offsets...)
end

@inline function _get_offset_in_record(
        record_type::Type, field_name::Symbol, record_layout::FixedRecordLayout)
    field_index = findfirst(fieldnames(record_type) .== field_name)
    fields_before = fieldnames(record_type)[1:(field_index - 1)]
    offset_in_record = sum(native_sizeof.(record_type, fields_before))
    return offset_in_record
end

function _get_field_array_size(
        record_layouts::Vector{FixedRecordLayout}, record_type::Type, field_name::Symbol)
    field_array_size = _get_array_size(record_type, field_name)
    return field_array_size
end

"""
    FlexibleRecordLayout

Used to store the record layout of flexible size data records in a Native metop files.
"""
struct FlexibleRecordLayout <: RecordLayout
    record_range::UnitRange{Int64}
    offsets::Vector{Int64}
    record_type::Type{<:Record}
    record_sizes::Vector{Int64}
    flexible_dims_file::Dict{Symbol, Int64}
    field_sizes::Matrix{Int64}
end

function read_record_layouts(file_pointer::IO, main_product_header::MainProductHeader,
        is_fixed_size::Val{false})::Vector{FlexibleRecordLayout}
    record_type = data_record_type(main_product_header)

    flexible_dims_file = _get_flexible_dims_file(file_pointer, record_type)

    flexible_dims_records = Dict{Symbol, Int64}[]
    offsets = Int64[]
    record_sizes = Int64[]

    record_start_pos, _ = _find_nth_record(file_pointer, record_type, 1)
    seek(file_pointer, record_start_pos)

    # read flexible dimensions and record offsets 
    while !eof(file_pointer)
        header = native_read(file_pointer, RecordHeader)

        if header_match_record_type(header, record_type)
            start_pos = position(file_pointer) - native_sizeof(RecordHeader)
            push!(offsets, start_pos)
            dims_record = _read_flex_dims_from_record_no_header(
                file_pointer, record_type, flexible_dims_file)
            push!(record_sizes, header.record_size)
            push!(flexible_dims_records, dims_record)
            seek(file_pointer, start_pos + header.record_size)
        else
            # Skip dummy records and similar.
            skip(file_pointer, header.record_size - native_sizeof(RecordHeader))
        end
    end

    record_count = length(offsets)
    fields = fieldnames(record_type)

    # compute offsets of all fields in all records.
    # This avoid duplicate computations when reading the variables.
    field_sizes = zeros(Int64, length(fields), record_count)
    for k in 1:length(fields)
        field_name = fields[k]
        f_type = fieldtype(record_type, field_name)

        is_field_fixed = fixed_size(record_type, field_name)
        if is_field_fixed
            field_size = 0
            if f_type <: Array
                array_size = _get_array_size(record_type, field_name)
                field_size = prod(array_size) * native_sizeof(eltype(f_type))
            else
                field_size = native_sizeof(f_type)
            end
            field_sizes[k, :] .= field_size
        else
            for i in 1:record_count
                array_size = _get_array_size_flexible_raw(record_type, field_name,
                    flexible_dims_file, flexible_dims_records[i])

                field_size = prod(array_size) * native_sizeof(eltype(f_type))

                field_sizes[k, i] = field_size
            end
        end
    end

    record_layout = FlexibleRecordLayout(
        1:length(offsets),
        offsets,
        record_type,
        record_sizes,
        flexible_dims_file,
        field_sizes
    )

    return [record_layout]
end

function _offset_in_record(record_layout::FlexibleRecordLayout, field_name::Symbol)
    field_index = findfirst(fieldnames(record_layout.record_type) .== field_name)
    size_of_fields_before = record_layout.field_sizes[1:(field_index - 1), :]

    offsets = dropdims(sum(size_of_fields_before, dims = 1), dims = 1)

    return offsets
end

@inline _layouts_to_offsets(record_layouts::Vector{FlexibleRecordLayout}) = copy(only(record_layouts).offsets)

@inline function _get_offset_in_record(
        record_type::Type, field_name::Symbol, record_layout::FlexibleRecordLayout)
    return _offset_in_record(record_layout, field_name)
end

function _get_field_array_size(
        record_layouts::Vector{FlexibleRecordLayout}, record_type::Type, field_name::Symbol)
    layout = only(record_layouts)

    field_array_size = _get_array_size_flexible(
        record_type, field_name,
        layout.flexible_dims_file, Dict{Symbol, Int64}())

    return field_array_size
end
