# Copyright (c) 2025 EUMETSAT
# License: MIT

struct DataElementFlags <: RecordSubType
    header::BitString{4}
    data::NTuple{20, BitString{2}}
end

get_header(val::DataElementFlags) = val.header
get_data(val::DataElementFlags) = val.data
