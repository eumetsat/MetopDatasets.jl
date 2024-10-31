# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    RecordChunk

Used to store the locations of different chunks of records in Native metop files.
"""
struct RecordChunk
    record_range::UnitRange{Int64}
    offset::Int64
    record_type::Type{<:Record}
end

"""
    get_data_record_chunks(internal_pointer_records::Vector{InternalPointerRecord},
        total_file_size::Integer, record_type::Type{<:DataRecord})::Vector{RecordChunk}

Compute the `record_chunks`
"""
function get_data_record_chunks(internal_pointer_records::Vector{InternalPointerRecord},
        total_file_size::Integer, record_type::Type{<:DataRecord})::Vector{RecordChunk}
    record_chunks = RecordChunk[]

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
        _add_record_chunk!(record_chunks, offset, byte_size, record_type_i)
    end

    return record_chunks
end

function _add_record_chunk!(record_chunks, offset, byte_size, record_type_i)
    record_size = native_sizeof(record_type_i)
    number_of_record = Int64(byte_size / record_size)
    chunk_of_type = filter(x -> x.record_type == record_type_i, record_chunks)

    index_start = isempty(chunk_of_type) ? 1 : chunk_of_type[end].record_range[end] + 1
    index_end = index_start - 1 + number_of_record
    push!(record_chunks, RecordChunk(index_start:index_end, offset, record_type_i))
    return nothing
end

function _chunks_to_offsets(record_chunks::Vector{RecordChunk})::Vector{<:Integer}
    record_size = native_sizeof(record_chunks[1].record_type)
    record_offsets = [record_size .* (c.record_range .- c.record_range[1]) .+ c.offset
                      for c in record_chunks]
    return vcat(record_offsets...)
end
