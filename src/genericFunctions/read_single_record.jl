# Copyright (c) 2024 EUMETSAT
# License: MIT

function header_match_record_type(header::RecordHeader, record_type::Type{<:Record})
    record_class = get_record_class(record_type)
    instrument_group = get_instrument_group(record_type)
    instrument_subclass = get_instrument_subclass(record_type)

    match = header.record_class == record_class
    match &= isnothing(instrument_group) ||
             (header.instrument_group == instrument_group)
    match &= isnothing(instrument_subclass) ||
             (header.instrument_subclass == instrument_subclass)

    if record_type <: DataRecord
        ## remove DummyRecords
        match &= header.instrument_group != get_instrument_group(DummyRecord)
    end

    return match
end

function _find_nth_record(file_pointer::IO, record_type::Type{<:Record}, n::Integer)
    @assert n > 0
    seekstart(file_pointer)

    while !eof(file_pointer)
        record_offset = position(file_pointer)
        header = native_read(file_pointer, RecordHeader)

        if header_match_record_type(header, record_type)
            n -= 1
            if n == 0
                return record_offset, header.record_size
            end
        end

        seek(file_pointer, record_offset + header.record_size)
    end

    return nothing, nothing
end

function read_single_record(file_pointer::IO, record_type::Type{<:Record}, n::Integer)
    record_offset, record_size = _find_nth_record(file_pointer, record_type, n)
    if isnothing(record_offset)
        return nothing
    end
    seek(file_pointer, record_offset)
    record = native_read(file_pointer, record_type)

    # Check that the correct number of bytes is read.
    bytes_read = position(file_pointer) - record_offset
    if record_size != bytes_read
        error("Error reading $record_type. Expected $record_size bytes, read $bytes_read bytes.")
    end

    return record
end

function read_single_record(
        file_path::AbstractString, record_type::Type{<:Record}, n::Integer)
    record = open(file_path) do file_pointer
        return read_single_record(file_pointer, record_type, n)
    end
    return record
end

"""
    read_first_record(source, record_type)::record_type

A simple alias for `read_single_record(source, record_type, 1)`
"""
read_first_record(source, record_type)::record_type = read_single_record(
    source, record_type, 1)

"""
    get_scaled(record::T, field::Union{AbstractString,Symbol}) where T <: BinaryRecord

Get the property from a data record type and apply scale factor if defined.
"""
function get_scaled(
        record::T, field::Union{AbstractString, Symbol}) where {T <: BinaryRecord}
    field = Symbol(field)
    scale_factor = get_scale_factor(T, field)
    raw_val = getproperty(record, field)
    if isnothing(scale_factor) || scale_factor == 0
        return raw_val
    else
        return raw_val / 10.0^scale_factor
    end
end
