# Copyright (c) 2024 EUMETSAT
# License: MIT

module MetopDatasets

using Dates: DateFormat, Day, Millisecond, Microsecond, format
import CommonDataModel as CDM
import CSV
import Dates: DateTime
import Base: size, keys, close, getindex
import DiskArrays
using Compat: @compat

include("abstractTypes/abstract_types.jl")
include("genericTypes/generic_types.jl")
include("genericFunctions/generic_functions.jl")
include("auto_generate_tools/auto_generate_tool.jl")
include("MetopDiskArray/MetopDiskArray.jl")
include("InterfaceDataModel/InterfaceDataModel.jl")

# Instruments 
include("Instruments/ASCAT/ASCAT.jl")
include("Instruments/IASI/IASI.jl")

const RECORD_DIM_NAME = "atrack"

export MetopDataset

# helper functions
export read_single_record, read_first_record, scale_iasi_spectrum, max_giadr_channel,
       brightness_temperature

# Function and types needed to extend the interface
@compat public record_struct_expression, data_record_type
@compat public get_cf_attributes, default_cf_attributes, default_variable
@compat public AbstractMetopDiskArray, MetopDiskArray, MetopVariable
@compat public MainProductHeader, RecordChunk, DataRecord

end
