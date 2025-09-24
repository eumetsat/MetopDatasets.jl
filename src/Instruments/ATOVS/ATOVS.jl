# Copyright (c) 2025 EUMETSAT
# License: MIT

abstract type ATOVS_1B <: DataRecord end

const DATA_CAL_NAME = :data_calibration
const DATA_CAL_NEDT_NAME = :data_calibration_nedt
const DATA_CAL_QUALITY_NAME = :data_calibration_quality

const ELEMENT_RAD_NAME = :digital_a_data_element_rad
const ELEMENT_RAD_DATA_NAME = :digital_a_rad
const ELEMENT_RAD_HEADER_NAME = :digital_a_rad_header

const ELEMENT_FLAG_NAME = :digital_a_data_element_flag
const ELEMENT_FLAG_DATA_NAME = :digital_a_flag
const ELEMENT_FLAG_HEADER_NAME = :digital_a_flag_header

const EXTRACTED_VARS = (DATA_CAL_NEDT_NAME, DATA_CAL_QUALITY_NAME, ELEMENT_RAD_DATA_NAME,
    ELEMENT_RAD_HEADER_NAME, ELEMENT_FLAG_DATA_NAME, ELEMENT_FLAG_HEADER_NAME)

const DATA_CAL_NEDT_DESCRIPTION = "Noise-Equivalent Delta Temperature"
const DATA_CAL_QUALITY_DESCRIPTION = "Channel Quality Flags"

include("MHS/MHS.jl")
include("AMSU_A/AMSU_A.jl")
include("HIRS/HIRS.jl")
include("VariableExtra.jl")
