# Copyright (c) 2025 EUMETSAT
# License: MIT

using MetopDatasets, Test
using Dates

test_data_artifact = MetopDatasets.get_test_data_artifact()

HIRS_test_file = joinpath(
    test_data_artifact, "HIRS_xxx_1B_M01_20241104213353Z_cropped_10.nat")

@testset "HIRS record type" begin
    @test MetopDatasets.native_sizeof(MetopDatasets.HIRS_XXX_1B_V10) == 6884
    @test MetopDatasets.fixed_size(MetopDatasets.HIRS_XXX_1B_V10)
    @test MetopDatasets.HIRS_XXX_1B_V10 <: MetopDatasets.ATOVS_1B
end

@testset "HIRS dataset" begin
    ds = MetopDataset(HIRS_test_file)

    @test all(-90 .< ds["earth_location"][1, :, :] .< 90)
    @test all(-180 .< ds["earth_location"][2, :, :] .< 180)

    @test "digital_a_rad" in keys(ds)
    @test "digital_a_rad_header" in keys(ds)
    
    @test size(ds["digital_a_rad"]) == (20, 56, 10)
    @test size(ds["digital_a_rad_header"]) == (56, 10)
end
