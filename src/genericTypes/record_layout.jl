# Copyright (c) 2024 EUMETSAT
# License: MIT

function _read_record_layouts(file_pointer::IO, main_product_header::MainProductHeader)
    record_type = data_record_type(main_product_header)
    return _read_record_layouts(
        file_pointer, main_product_header, Val(fixed_size(record_type)))
end

"""
    FixedRecordLayout

Used to store the locations of different layouts of records in Native metop files.
"""
struct FixedRecordLayout <: RecordLayout
    record_range::UnitRange{Int64}
    offset::Int64
    record_type::Type{<:Record}
end

function _read_record_layouts(file_pointer::IO, main_product_header::MainProductHeader,
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

    record_layouts = get_data_record_layouts(internal_pointer_records,
        total_file_size,
        record_type)

    return record_layouts
end

"""
    get_data_record_layouts(internal_pointer_records::Vector{InternalPointerRecord},
        total_file_size::Integer, record_type::Type{<:DataRecord})::Vector{FixedRecordLayout}

Compute the `record_layouts`
"""
function get_data_record_layouts(internal_pointer_records::Vector{InternalPointerRecord},
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

"""
    FlexibleRecordLayout

Used to store the locations of different layouts of records in Native metop files.
"""
struct FlexibleRecordLayout <: RecordLayout
    record_range::UnitRange{Int64}
    offsets::Vector{Int64}
    record_type::Type{<:Record}
    record_sizes::Vector{Int64}
    flexible_dims_file::Dict{Symbol, Int64}
    flexible_dims_records::Vector{Dict{Symbol, Int64}}
end

function _read_record_layouts(file_pointer::IO, main_product_header::MainProductHeader,
        fixed_size::Val{false})::Vector{FlexibleRecordLayout}
    record_type = data_record_type(main_product_header)

    flexible_dims_file = get_flexible_dims_file(file_pointer, record_type)

    flexible_dims_records = Dict{Symbol, Int64}[]
    offsets = Int64[]
    record_sizes = Int64[]

    record_start_pos, _ = _find_nth_record(file_pointer, record_type, 1)
    seek(file_pointer, record_start_pos)

    while !eof(file_pointer)
        header = native_read(file_pointer, RecordHeader)

        if header_match_record_type(header, record_type)
            push!(offsets, position(file_pointer) - native_sizeof(RecordHeader))
            dims_record = _read_flex_dims_from_record_no_header(
                file_pointer, record_type, flexible_dims_file)
            push!(record_sizes, header.record_size)
            push!(flexible_dims_records, dims_record)
        else
            # Skip dummy records and similar.
            skip(file_pointer, header.record_size - native_sizeof(RecordHeader))
        end
    end

    record_layout = FlexibleRecordLayout(
        1:length(offsets),
        offsets,
        record_type,
        record_sizes,
        flexible_dims_file,
        flexible_dims_records
    )

    return [record_layout]
end

function get_flex_dim_max(layout::FlexibleRecordLayout, dim_name::Symbol)
    if haskey(layout.flexible_dims_file, dim_name)
        return layout.flexible_dims_file[dim_name]
    end

    dim_max = max([dims_record[dim_name] for dims_record in layout.flexible_dims_records]...)
    return dim_max
end

function get_flex_dim_max(layout::FlexibleRecordLayout)
    all_keys = keys(first(layout.flexible_dims_records))
    max_flex_dims = Dict(all_keys .=> (get_flex_dim_max(layout, k) for k in all_keys))
    return max_flex_dims
end
