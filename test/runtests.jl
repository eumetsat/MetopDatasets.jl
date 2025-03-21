# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Test, Aqua, SafeTestsets

if !isdir("testData") #TODO test data should be handle as an artifact or something similar.
    println("Skipping tests that needs real test data")
end

@testset "MetopDatasets.jl" begin
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

    @safetestset "Main product header" begin
        if isdir("testData")
            include("main_product_header.jl")
        end
    end

    @safetestset "MetopDiskArray" begin
        if isdir("testData")
            include("MetopDiskArray.jl")
        end
    end

    @safetestset "MetopDataset" begin
        if isdir("testData")
            include("Dataset.jl")
        end
    end

    @safetestset "Convert to netCDF" begin
        if isdir("testData")
            include("conversions.jl")
        end
    end

    Aqua.test_all(MetopDatasets)
end
