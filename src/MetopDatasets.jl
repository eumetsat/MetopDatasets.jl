# Copyright (c) 2024 EUMETSAT
# License: MIT

module MetopDatasets

using Dates: DateFormat, Day, Millisecond, Microsecond, format
import CommonDataModel as CDM
import CSV
import Dates: DateTime
import Base: size, keys, close, getindex, parent
import DiskArrays
using Compat: @compat
using PrecompileTools: @setup_workload, @compile_workload
using RelocatableFolders: @path
import LazyArtifacts

const RECORD_DIM_NAME = "atrack"

include("abstractTypes/abstract_types.jl")
include("genericTypes/generic_types.jl")
include("genericFunctions/generic_functions.jl")
include("auto_generate_tools/auto_generate_tool.jl")
include("MetopDiskArray/MetopDiskArray.jl")
include("MetopDiskArray/FlexibleMetopDiskArray.jl")
include("MetopDiskArray/construct_disk_array.jl")
include("InterfaceDataModel/InterfaceDataModel.jl")

# Instruments 
include("Instruments/ASCAT/ASCAT.jl")
include("Instruments/IASI/IASI.jl")

"""
    get_test_data_artifact()

Returns path to folder storing reduced test data. Note that the test data is downloaded from https://github.com/eumetsat/test-data-MetopDatasets
the first time the function it called.
"""
get_test_data_artifact() = joinpath(
        LazyArtifacts.artifact"test_data_MetopDatasets", "reduced_data")

export MetopDataset

# helper functions
export read_single_record, read_first_record, scale_iasi_spectrum, max_giadr_channel,
       brightness_temperature

# export cfvariable to enable maskingvalue 
cfvariable = CDM.cfvariable
dimnames = CDM.dimnames
export cfvariable, dimnames

# Function and types needed to extend the interface
@compat public record_struct_expression, data_record_type
@compat public get_cf_attributes, default_cf_attributes, default_variable
@compat public AbstractMetopDiskArray, MetopDiskArray, MetopVariable
@compat public MainProductHeader, FixedRecordLayout, DataRecord
@compat public get_test_data_artifact

# Precompile
@setup_workload begin
    test_data_artifact = get_test_data_artifact()
    test_files = readdir(test_data_artifact, join = true)

    @compile_workload begin
        # Store some output.
        io_list = []
        var_size = []

        for file in test_files
            MetopDataset(file) do ds
                # Precompile display
                io = IOBuffer()
                show(io, ds)
                push!(io_list, String(take!(io)))
                # Precompile readers
                for k in keys(ds)
                    var_out = Array(ds[k])
                    push!(var_size, sizeof(var_out))
                end
            end
        end

        io_list, var_size
    end
end

end
