# Copyright (c) 2024 EUMETSAT
# License: MIT

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
