using MetopDatasets, Test
using Dates

test_data_artifact = MetopDatasets.get_test_data_artifact()

MHS_test_file = joinpath(
    test_data_artifact, "MHSx_xxx_1B_M03_20250915084851Z_cropped_10.nat")

@testset "MHS record type" begin
    @test MetopDatasets.native_sizeof(MetopDatasets.MHS_XXX_1B_V10) == 4316
    @test MetopDatasets.fixed_size(MetopDatasets.MHS_XXX_1B_V10)
    @test MetopDatasets.MHS_XXX_1B_V10 <: MetopDatasets.ATOVS_1B

    field_index = findfirst(fieldnames(MetopDatasets.MHS_XXX_1B_V10) .== :data_calibration)
    @test field_index == 63
    @test fieldtypes(MetopDatasets.MHS_XXX_1B_V10)[field_index] <:
          Vector{MetopDatasets.DataCalibrationQuality}
end

@testset "GIADR_MHS_RADIANCE" begin
    @test MetopDatasets.native_sizeof(MetopDatasets.GIADR_MHS_RADIANCE) == 478
    @test MetopDatasets.fixed_size(MetopDatasets.GIADR_MHS_RADIANCE)
    @test MetopDatasets.GIADR_MHS_RADIANCE <: MetopDatasets.GlobalInternalAuxillary

    mhs_giadr = read_first_record(MHS_test_file, MetopDatasets.GIADR_MHS_RADIANCE)
    speed_of_light = 299792458

    f1 = 10.0^2 * get_scaled(mhs_giadr, "central_wavenumber_h1") * speed_of_light
    @test isapprox(f1, 89.0E9, rtol = 0.01) # 89.0 GHz

    f4 = 10.0^2 * get_scaled(mhs_giadr, "central_wavenumber_h4") * speed_of_light
    @test isapprox(f4, 183.311E9, rtol = 0.01) # 183.311 GHz
end

@testset "MHS dataset" begin
    ds = MetopDataset(MHS_test_file)

    @test all(-90 .< ds["earth_location"][1, :, :] .< 90) # latitude
    @test all(-180 .< ds["earth_location"][2, :, :] .< 180) # longitude

    radiance_2 = ds["scene_radiances"][2, :, :]
    @test radiance_2 isa Matrix{Union{Missing, Float64}}

    # scale to temperature
    mhs_giadr = read_first_record(ds, MetopDatasets.GIADR_MHS_RADIANCE)
    wave_number_2 = get_scaled(mhs_giadr, "central_wavenumber_h2")
    T_brightness_uncorrected_2 = brightness_temperature.(
        radiance_2 * 10^(-5), wave_number_2 * 10.0^2)
    @test all(150 .< T_brightness_uncorrected_2 .< 300) # temperature in Kelvin

    # Check data_calibration
    @test !("data_calibration" in keys(ds))
    @test "data_calibration_quality" in keys(ds)
    @test "data_calibration_nedt" in keys(ds)
    @test all(0.25 .< ds["data_calibration_nedt"][2, :] .< 0.50)
end
