# Copyright (c) 2025 EUMETSAT
# License: MIT

using MetopDatasets, Test, Dates
import CommonDataModel as CDM

function get_data_record_type(file)
    data_record_type = open(file, "r") do file_pointer
        main_header = MetopDatasets.native_read(
            file_pointer, MetopDatasets.MainProductHeader)
        return MetopDatasets.data_record_type(main_header)
    end
    return data_record_type
end

@testset "Test old ASCAT formats" begin
    SZR_V12_test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"
    @test get_data_record_type(SZR_V12_test_file) == MetopDatasets.ASCA_SZR_1B_V12

    SZF_V11_test_file = "testData/ASCA_SZF_1B_M02_20111207032400Z_20111207050859Z_R_O_20130827153404Z_0200.nat"
    ds = MetopDataset(SZF_V11_test_file)

    # check times to sample start and end of file.
    @test abs(DateTime(ds.attrib["sensing_start"]) - ds["utc_localisation"][1]) <
          Second(2)
    @test abs(DateTime(ds.attrib["sensing_end"]) - ds["utc_localisation"][end]) <
          Second(2)
end

@testset "SZF with dummy record" begin
    SZF_with_dummy_in_mid = "testData/ASCA_SZF_1B_M01_20221107123600Z_20221107141459Z_N_O_20221107132528Z.nat"
    ds = MetopDataset(SZF_with_dummy_in_mid)

    # check the number of records
    total_count = parse(Int, ds.attrib["total_mdr"])
    data_count = ds.dim[MetopDatasets.RECORD_DIM_NAME]
    dummy_count = 3 # the product have 3 dummy records
    @test total_count ==
          (data_count + dummy_count)

    # check that longitude and latitude are in the correct range
    longitude = Array(ds["longitude_full"])
    latitude = Array(ds["latitude_full"])

    @test all((0 .<= longitude) .& (longitude .<= 360))
    @test all((-90 .<= latitude) .& (latitude .<= 90))

    # test time stamps
    @test abs(DateTime(ds.attrib["sensing_start"]) - ds["utc_localisation"][1]) <
          Second(2)
    @test abs(DateTime(ds.attrib["sensing_end"]) - ds["utc_localisation"][end]) <
          Second(2)
end

@testset "IASI L02 V10 data records" begin
    test_file = "testData/IASI_SND_02_M02_20100202135952Z_20100202153856Z_N_O_20100202154539Z.nat"

    ds = MetopDataset(test_file)

    # test size
    @test ds.dim[MetopDatasets.RECORD_DIM_NAME] == parse(Int, ds.attrib["total_mdr"])

    @test Array(ds["pressure_levels_temp"]) isa Vector{Union{Missing, Float64}}
    @test MetopDatasets.CDM.dimnames(ds["pressure_levels_ozone"]) ==
          ["n_o3_profiles", "NLO"]

    @test all(lat -> -90 < lat < 90, ds["earth_location"][1, :, :])
    @test all(lon -> -180 < lon < 180, ds["earth_location"][2, :, :])

    # test error field
    error_field_dims = Int.(ds["data_sizes"][:, :, :])
    elem_size = 5
    error_field_size_computed = [sum(error_field_dims[1, :, i] * elem_size)
                                 for i in 1:ds.dim["atrack"]]
    error_field = ds["error_data"][49]

    @test error_field isa Vector{UInt8}
    @test length(error_field) == error_field_size_computed[49]
    @test length.(ds["error_data"][1:2]) == error_field_size_computed[1:2]

    close(ds)
end

@testset "GOME-2 L1B V12 dataset" begin
    test_file = "testData/GOME_xxx_1B_M01_20200610023257Z_20200610041457Z_R_O_20201017155136Z_0300.nat"

    ds = MetopDataset(test_file)
    @test ds.main_product_header.format_major_version == 12
    @test "earthshine" in keys(ds.group)
    @test "calibration" in keys(ds.group)
    ds_earthshine = ds.group["earthshine"]
    @test typeof(ds_earthshine).parameters[1] == MetopDatasets.GOME_XXX_1B_EARTHSHINE_V12

    centre_var = CDM.variable(ds_earthshine, "centre")
    @test CDM.attrib(centre_var, "geo_component_order") == "latitude, longitude"

    centre = CDM.variable(ds_earthshine, "centre")[:, :, 1]
    lat = ds_earthshine["latitude"][:, 1]
    lon = ds_earthshine["longitude"][:, 1]
    
    @test  all(-90 .< lat .< 90)
    @test  all(-180 .< lon .< 180)

    lat_expected = [MetopDatasets._decode_centre_component(centre, s, 1) * 1e-6
                    for s in 1:32]
    lon_expected = [MetopDatasets._decode_centre_component(centre, s, 2) * 1e-6
                    for s in 1:32]
    @test all(isapprox.(lat, lat_expected; atol = 1e-10, rtol = 0))
    @test all(isapprox.(lon, lon_expected; atol = 1e-10, rtol = 0))

    @test ds_earthshine.dim["atrack"] == 599
    
    ds_calibration = ds.group["calibration"]
    @test ds_calibration.dim["atrack"] == 407
    
    rads = ds_calibration["radiance_3"][:,:,130]
    channels = ds_calibration["rec_length_3"][130]
    read_outs = ds_calibration["num_recs_3"][130]
    @test any(ismissing, rads)    
    @test !any(ismissing, rads[1:channels,1:read_outs])    
    
    @test_throws "Variable `latitude` is only defined for Earthshine MDRs" ds_calibration["latitude"]

    close(ds)
end


@testset "GOME-2 L1B moon" begin
    test_file = "testData/GOME_xxx_1B_M01_20260803162356Z_20260803162656Z_N_O_20260803171920Z"

    ds = MetopDataset(test_file);

    @test ds.main_product_header.format_major_version == 13
    @test "moon" in keys(ds.group)
    ds_moon = ds.group["moon"]

    @test CDM.dimnames(ds_moon["lunar_azimuth"]) == ["lunar_point", "atrack"]
    @test CDM.dimnames(ds_moon["lunar_elevation"]) == ["lunar_point", "atrack"]
    @test all(-180 .< ds_moon["lunar_phase"][:] .< 180)
    

    rad_var = CDM.variable(ds_moon, "radiance_1a")
    @test CDM.attrib(rad_var, "units") == "photon s-1 cm-2 nm-1 sr-1"
    @test CDM.attrib(rad_var, "output_selection_mode") == "lunar_radiance"

    @test_throws "Variable `latitude` is only defined for Earthshine MDRs" ds_moon["latitude"]
    @test ds_moon.dim["atrack"] == 30

    # During Moon calibration, the main spectrometer channels (1a-4)
    # record no signal — the granule contains EUMETSAT fill markers
    # (typemin(Int8)/typemin(Int32)) for those bands. PMD broadband
    # channels capture the lunar reflectance and decode to real
    # photon-flux radiances. This split is the parser's main correctness
    # signal for Moon data: a regression that confuses fill vs. real
    # values would flip both behaviours.
    for band_name in ("1a", "1b", "3", "4")
        v = ds_moon["radiance_$band_name"][:, :, :]
        finite = [x for x in vec(v) if !ismissing(x) && isfinite(x)]
        @test isempty(finite)  # all instrument-fill, by design
    end
    for band_name in ("pp", "ps", "swps")
        v = ds_moon["radiance_$band_name"][:, :, :]
        finite = [x for x in vec(v) if !ismissing(x) && isfinite(x)]
        @test length(finite) > 1000
    end

    close(ds)
end


@testset "GOME-2 L1B calibration" begin
    test_file = "testData/GOME_xxx_1B_M01_20260711223859Z_20260711224159Z_N_O_20260711233840Z"

    ds = MetopDataset(test_file);

    @test ds.main_product_header.format_major_version == 13
    @test "calibration" in keys(ds.group)
    ds_calibration = ds.group["calibration"]

    @test ds_calibration.dim["atrack"] == 12

    rads = ds_calibration["radiance_3"][:,:,6]
    channels = ds_calibration["rec_length_3"][6]
    read_outs = ds_calibration["num_recs_3"][6]   
    @test !any(ismissing, rads[1:channels,1:read_outs])  
    @test_throws "Variable `latitude` is only defined for Earthshine MDRs" ds_calibration["latitude"]

    rad_var = CDM.variable(ds_calibration, "radiance_1a")
    @test CDM.attrib(rad_var, "units") == "photon s-1 cm-2 nm-1 sr-1"
    # Mode is derived from per-record OBSERVATION_MODE; one of the
    # calibration_* labels.
    mode = CDM.attrib(rad_var, "output_selection_mode")
    @test startswith(mode, "calibration_")
    @test occursin("dark", CDM.attrib(rad_var, "comment"))
end


@testset "GOME-2 L1B sun" begin
    test_file = "testData/GOME_xxx_1B_M01_20260712125658Z_20260712125958Z_N_O_20260712132857Z"

    ds = MetopDataset(test_file);
    @test ds.main_product_header.format_major_version == 13
    @test "sun" in keys(ds.group)
    ds_sun = ds.group["sun"]

    # "FPA temperature uses main_bands dimension" 
    fpa = ds_sun["fpa_temp"]
    @test size(fpa, 1) == 6
    @test CDM.dimnames(fpa) == ["main_bands", "atrack"]
    @test CDM.dim(ds_sun, "main_bands") == 6

    # "Earthshine-only variables gated on non-Earthshine subclass" begin
    @test_throws "Variable `latitude` is only defined for Earthshine MDRs" ds_sun["latitude"]

    # "Sun measurement-mode metadata" 
    rad_var = CDM.variable(ds_sun, "radiance_1a")
    @test CDM.attrib(rad_var, "units") == "photon s-1 cm-2 nm-1"
    @test CDM.attrib(rad_var, "output_selection_mode") == "solar_irradiance"

    # "Sun radiance has finite values across bands"
    # Regression guard for `_decode_vinteger_or_nan`: a bug that silently
    # turns real readings into fill (or fill into spurious finite
    # garbage) would slip past the shape/metadata checks above.
    ds_sun = CDM.group(ds, "sun")
    for band_name in ("1a", "3", "pp")
        v = ds_sun["radiance_$band_name"][:, :, :]
        finite = [x for x in vec(v) if !ismissing(x) && isfinite(x)]
        @test !isempty(finite)
        @test length(finite) > 100
    end
end