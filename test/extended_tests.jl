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

    SZF_V11_test_file = "testData/ASCA_SZF_1B_M02_20111207032400Z_20111207050859Z_N_O_20111207041515Z.nat"
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
