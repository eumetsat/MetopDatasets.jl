# Copyright (c) 2025 EUMETSAT
# License: MIT

struct DataElementRadiance <: RecordSubType
    header::BitString{4}
    data::NTuple{20, Int32}
end

get_header(val::DataElementRadiance) = val.header
get_data(val::DataElementRadiance) = val.data
