# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    InternalPointerRecord <: Record

The Internal Pointer Records (IPR) specifies the start of each block of records in the file
sharing the same record type. This can be used to find the locations of data records or dummy records.
"""
struct InternalPointerRecord <: Record
    record_header::RecordHeader
    record_class::UInt8
    instrument_group::UInt8
    instrument_subclass::UInt8
    record_offset::UInt32
end

native_sizeof(T::Type{InternalPointerRecord}) = 27
