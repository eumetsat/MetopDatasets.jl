using MetopDatasets, Test
using Dates

test_data_artifact = MetopDatasets.get_test_data_artifact()

AMSA_test_file = joinpath(
    test_data_artifact, "AMSA_xxx_1B_M03_20250915221320Z_cropped_10.nat")

@testset "AMSU-A record type" begin
    @test MetopDatasets.native_sizeof(MetopDatasets.AMSA_XXX_1B_V10) == 3464
    @test MetopDatasets.fixed_size(MetopDatasets.AMSA_XXX_1B_V10)
    @test MetopDatasets.AMSA_XXX_1B_V10 <: MetopDatasets.ATOVS_1B
end

@testset "AMSU-A dataset" begin
    ds = MetopDataset(AMSA_test_file)

    @test all(0.001 .< ds["scene_radiance"][2, :, :] .< 0.003)
    @test all(0.1 .< ds["data_calibration_nedt"][2, :] .< 0.3)
    @test all(-90 .< ds["earth_location"][1, :, :] .< 90)
    @test all(-180 .< ds["data_calibration_nedt"][2, :] .< 180)
end
