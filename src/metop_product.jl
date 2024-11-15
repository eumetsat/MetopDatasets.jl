# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    MetopProduct{T <: DataRecord} 
        main_product_header::MainProductHeader
        internal_pointer_records::Vector{InternalPointerRecord}
        data_records::Vector{T}
        dummy_records::Vector{DummyRecord}

Generic Metop Product
"""
struct MetopProduct{T <: DataRecord}
    main_product_header::MainProductHeader
    #TODO secondary_product_header::Union{SecondaryProductHeader, Nothing} 
    internal_pointer_records::Vector{InternalPointerRecord}
    #TODO external_auxiliary_records::Vector{ExternalAuxiliaryRecord}
    #TODO internal_auxiliary_records::Vector{InternalAuxiliaryRecord}
    data_records::Vector{T}
    dummy_records::Vector{DummyRecord}
end

"""
    MetopProduct(file_path::AbstractString)
        main_product_header::MainProductHeader
        internal_pointer_records::Vector{InternalPointerRecord}
        data_records::Vector{T}
        dummy_records::Vector{DummyRecord}

Construct a MetopProduct from a file. This allows you to load the entire native file with one function.
"""
function MetopProduct(file_path::AbstractString)
    return open(f -> native_read(f, MetopProduct), file_path, "r")
end

function native_read(file_pointer::IO, T::Type{MetopProduct})::MetopProduct
    main_product_header = native_read(file_pointer, MainProductHeader)
    record_type = data_record_type(main_product_header)

    # skip secondary header if present
    _skip_sphr(file_pointer, main_product_header.total_sphr)

    record_chunks, internal_pointer_records = _read_record_chunks(file_pointer,
        main_product_header)

    # read records
    data_records = _read_records(file_pointer, record_chunks, record_type)
    dummy_records = _read_records(file_pointer, record_chunks, DummyRecord)

    # check number of records.
    if main_product_header.total_mdr != (length(data_records) + length(dummy_records))
        @warn "The number of data/dummy records does not match the product header. Expected $(main_product_header.total_mdr), got $length(data_records) + $length(dummy_records)"
    end

    return MetopProduct{record_type}(main_product_header,
        internal_pointer_records,
        data_records,
        dummy_records)
end

function _read_records(file_pointer, record_chunks, record_type::Type)::Vector{record_type}
    record_chunks_t = filter(x -> x.record_type == record_type, record_chunks)
    record_count = sum([length(chunk.record_range) for chunk in record_chunks_t])
    records = Vector{record_type}(undef, record_count)
    for chunk in record_chunks_t
        seek(file_pointer, chunk.offset)
        for i in chunk.record_range
            records[i] = native_read(file_pointer, record_type)
        end
    end
    return records
end

function _skip_sphr(file_pointer, n_headers)
    for _ in 1:n_headers
        record_header = native_read(file_pointer, RecordHeader)
        @assert record_header.record_class == get_record_class(SecondaryProductHeader)
        content_size = record_header.record_size - native_sizeof(RecordHeader)
        skip(file_pointer, content_size)
    end
    return nothing
end

function _read_record_chunks(file_pointer::IO, main_product_header::MainProductHeader)
    record_type = data_record_type(main_product_header)

    # read internal pointer records
    internal_pointer_records = Vector{InternalPointerRecord}(undef,
        main_product_header.total_ipr)
    for i in eachindex(internal_pointer_records)
        internal_pointer_records[i] = native_read(file_pointer, InternalPointerRecord)
    end

    # get record chunks
    total_file_size = main_product_header.actual_product_size

    record_chunks = get_data_record_chunks(internal_pointer_records,
        total_file_size,
        record_type)

    return record_chunks, internal_pointer_records
end
