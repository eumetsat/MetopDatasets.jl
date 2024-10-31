# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    RecordHeader

Also known as GRH.
"""
struct RecordHeader <: RecordSubType
    record_class::UInt8
    instrument_group::UInt8
    instrument_subclass::UInt8
    instrument_subclass_version::UInt8
    record_size::UInt32
    record_start_time::ShortCdsTime
    record_stop_time::ShortCdsTime
end
