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
include("Instruments/ATOVS/ATOVS.jl")

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
       brightness_temperature, get_scaled

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
    file_names = [
        "ASCA_SZF_1B_M03_20241217091500Z_cropped_10.nat",
        "ASCA_SZO_1B_M03_20250504214500Z_cropped_10.nat",
        "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat",
        "MHSx_xxx_1B_M03_20250915084851Z_cropped_10.nat",
        "IASI_SND_02_M03_20250120105357Z_cropped_10.nat",
        "IASI_xxx_1C_M01_20240925202059Z_cropped_5.nat",]

    test_files = joinpath.(test_data_artifact, file_names)


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
