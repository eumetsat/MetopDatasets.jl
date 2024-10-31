# Copyright (c) 2024 EUMETSAT
# License: MIT

module MetopNative

using Dates: DateFormat, Day, Millisecond, Microsecond, format
import CommonDataModel as CDM
import CSV
import Dates: DateTime
import Base: size, keys, close, getindex
import DiskArrays

include("abstractTypes/abstract_types.jl")
include("genericTypes/generic_types.jl")
include("genericFunctions/generic_functions.jl")
include("auto_generate_tools/auto_generate_tool.jl")
include("MetopDiskArray/MetopDiskArray.jl")
include("InterfaceDataModel/InterfaceDataModel.jl")
include("metop_product.jl")

# Instruments 
include("Instruments/ASCAT/ASCAT.jl")
include("Instruments/IASI/IASI.jl")

const RECORD_DIM_NAME = "atrack"

export Record, DataRecord, MetopProduct, MetopDataset

end
