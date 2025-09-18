abstract type ATOVS_1B <: DataRecord end

const DATA_CAL_NEDT_NAME = :data_calibration_nedt
const DATA_CAL_QUALITY_NAME = :data_calibration_quality
const DATA_CAL_NAME = :data_calibration

const DATA_CAL_NEDT_DESCRIPTION = "Noise-Equivalent Delta Temperature"
const DATA_CAL_QUALITY_DESCRIPTION = "Channel Quality Flags"

include("MHS/MHS.jl")
include("AMSU_A/AMSU_A.jl")
include("VariableExtra.jl")
