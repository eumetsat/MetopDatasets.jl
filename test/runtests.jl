# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Test, Aqua, SafeTestsets

@safetestset "Auto generate structs" begin
    include("auto_generate.jl")
end

@safetestset "Generic functions" begin
    include("generic_functions.jl")
end

@safetestset "Generic types" begin
    include("generic_types.jl")
end

@safetestset "Record layouts" begin
    include("record_layout.jl")
end

@safetestset "ASCAT" begin
    include("ASCAT.jl")
end

@safetestset "IASI" begin
    include("IASI.jl")
end

@safetestset "MHS" begin
    include("MHS.jl")
end

@safetestset "Main product header" begin
    include("main_product_header.jl")
end

@safetestset "MetopDiskArray" begin
    include("MetopDiskArray.jl")
end

@safetestset "MetopDataset" begin
    include("Dataset.jl")
end

@safetestset "Convert to netCDF" begin
    include("conversions.jl")
end

Aqua.test_all(MetopDatasets)

@safetestset "Extended tests" begin
    if isdir("testData")
        @info "Running extended tests"
        include("extended_tests.jl")
    else
        @info "Skipping extended tests"
    end
end
