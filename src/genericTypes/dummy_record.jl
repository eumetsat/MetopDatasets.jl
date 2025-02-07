# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    DummyRecord <:Record

The Dummy Measurement Data Record is a special case of the MDR. It is a generic
record that is used to indicate the location of lost data within any product. One DMDR
can replace a contiguous block of lost MDRs
"""
struct DummyRecord <: BinaryRecord
    record_header::RecordHeader
    spare_flag::UInt8 ## not used
end

native_sizeof(::Type{DummyRecord}) = 21
