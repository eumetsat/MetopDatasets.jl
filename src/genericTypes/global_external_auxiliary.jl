# Copyright (c) 2026 EUMETSAT
# License: MIT

struct GlobalExternalAuxiliary <: Record
    record_header::RecordHeader
    content::String
end


function native_read(io::IO, T::Type{GlobalExternalAuxiliary})::GlobalExternalAuxiliary
    record_header = native_read(io, RecordHeader)
    
    # read the content
    content_size = record_header.record_size - native_sizeof(RecordHeader)
    record_content_bytes = Array{UInt8}(undef, content_size)
    read!(io, record_content_bytes)

    #extract the values as string
    record_content = strip(String(ntoh.(record_content_bytes)))

    return GlobalExternalAuxiliary(record_header, record_content)
end