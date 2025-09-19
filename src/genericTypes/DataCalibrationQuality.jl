# Copyright (c) 2025 EUMETSAT
# License: MIT

struct DataCalibrationQuality <: RecordSubType
    noise_temperature::UInt8
    calibration_quality::BitString{1}
end

get_noise_temperature(val::DataCalibrationQuality) = val.noise_temperature
get_calibration_quality(val::DataCalibrationQuality) = val.calibration_quality
