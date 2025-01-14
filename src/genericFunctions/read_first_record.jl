# Copyright (c) 2024 EUMETSAT
# License: MIT

function _find_first_record(file_pointer::IO, record_type::Type{<:Record})
    seekstart(file_pointer)

    record_class = get_record_class(record_type)
    instrument_group = get_instrument_group(record_type)
    instrument_subclass = get_instrument_subclass(record_type)

    while !eof(file_pointer)
        record_offset = position(file_pointer)
        header = native_read(file_pointer, RecordHeader)

        match = header.record_class == record_class
        match &= isnothing(instrument_group) ||
                 (header.instrument_group == instrument_group)
        match &= isnothing(instrument_subclass) ||
                 (header.instrument_subclass == instrument_subclass)

        if match
            return record_offset
        end

        seek(file_pointer, record_offset + header.record_size)
    end

    return -1
end

function read_first_record(file_pointer::IO, record_type::Type{<:Record})
    record_offset = _find_first_record(file_pointer, record_type)
    seek(file_pointer, record_offset)
    return native_read(file_pointer, record_type)
end

function read_first_record(file_path::AbstractString, record_type::Type{<:Record})
    record = open(file_path) do file_pointer
        return read_first_record(file_pointer, record_type)
    end
    return record
end