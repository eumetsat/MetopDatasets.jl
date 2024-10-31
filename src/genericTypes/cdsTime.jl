# Copyright (c) 2024 EUMETSAT
# License: MIT

abstract type CdsTime <: RecordSubType end

struct ShortCdsTime <: CdsTime
    day::UInt16
    millisecond::UInt32
end

struct LongCdsTime <: CdsTime
    day::UInt16
    millisecond::UInt32
    microsecond::UInt16
end

const EPOCH_TIME = DateTime(2000, 1, 1, 0)
const SECONDS_PER_DAY = 24 * 60 * 60.0

function _corse_time(timestamp::CdsTime)
    return EPOCH_TIME + Day(timestamp.day) + Millisecond(timestamp.millisecond)
end

DateTime(timestamp::ShortCdsTime) = _corse_time(timestamp)

# this truncates LongCdsTime to nearest millisecond. Consider using  TimesDates.jl for more precision
function DateTime(timestamp::LongCdsTime)
    return _corse_time(timestamp) + Microsecond(timestamp.microsecond)
end

function seconds_since_epoch(timestamp::ShortCdsTime)::Float64
    return timestamp.day * SECONDS_PER_DAY + timestamp.millisecond / 10^3
end

function seconds_since_epoch(timestamp::LongCdsTime)::Float64
    return timestamp.day * SECONDS_PER_DAY + timestamp.millisecond / 10^3 +
           timestamp.microsecond / 10^6
end
