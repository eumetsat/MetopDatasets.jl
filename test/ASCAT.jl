# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test
using Dates

test_data_artifact = joinpath("../reduced_data", "reduced_data")

SZO_V13_test_file = joinpath(
    test_data_artifact, "ASCA_SZO_1B_M03_20250504214500Z_cropped_10.nat")
SZR_V13_test_file = joinpath(
    test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")
SZF_V13_test_file = joinpath(
    test_data_artifact, "ASCA_SZF_1B_M03_20241217091500Z_cropped_10.nat")
SMO_V12_test_file = joinpath(
    test_data_artifact, "ASCA_SMO_02_M01_20250504205100Z_cropped_10.nat")
SMR_V12_test_file = joinpath(
    test_data_artifact, "ASCA_SMR_02_M01_20241217081500Z_cropped_10.nat")

function test_dimensions(record_type)
    fields = fieldnames(record_type)
    return !isnothing(MetopDatasets.get_field_dimensions.(record_type, fields))
end

@testset "ASCAT data records types" begin
    ## ASCA_SZR_1B_V13
    @test MetopDatasets.ASCA_SZR_1B_V13 <: MetopDatasets.DataRecord
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZR_1B_V13) == 6677
    @test MetopDatasets.fixed_size(MetopDatasets.ASCA_SZR_1B_V13) == true
    @test test_dimensions(MetopDatasets.ASCA_SZR_1B_V13)

    field_index = findfirst(fieldnames(MetopDatasets.ASCA_SZR_1B_V13) .== :sigma0_trip)
    @test field_index == 11
    @test fieldtypes(MetopDatasets.ASCA_SZR_1B_V13)[field_index] <: Matrix{Int32}

    ## test that all arrays have length > 1
    is_array_field = fieldtypes(MetopDatasets.ASCA_SZR_1B_V13) .<: Array
    array_field_names = [fieldnames(MetopDatasets.ASCA_SZR_1B_V13)...][[is_array_field...]]
    raw_array_dimensions = MetopDatasets.get_raw_format_dim.(
        MetopDatasets.ASCA_SZR_1B_V13, array_field_names)
    @test all([prod(elem) > 1 for elem in raw_array_dimensions])

    @test MetopDatasets.get_scale_factor(MetopDatasets.ASCA_SZR_1B_V13, :sigma0_trip) == 6
    @test MetopDatasets.get_dimensions(MetopDatasets.ASCA_SZR_1B_V13) ==
          Dict("num_band" => 3, "xtrack" => 82)
    @test MetopDatasets.get_field_dimensions(MetopDatasets.ASCA_SZR_1B_V13, :sigma0_trip) ==
          ["num_band", "xtrack"]
    @test MetopDatasets.get_field_dimensions(
        MetopDatasets.ASCA_SZR_1B_V13, :abs_line_number) ==
          String[]
    @test MetopDatasets.get_description(MetopDatasets.ASCA_SZR_1B_V13, :sigma0_trip) ==
          "Sigma0 triplet, re-sampled to swath grid, for 3 beams (fore, mid, aft) "

    # other formats
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZO_1B_V13) == 3437
    @test test_dimensions(MetopDatasets.ASCA_SZO_1B_V13)
    @test MetopDatasets.get_scale_factor(MetopDatasets.ASCA_SZO_1B_V13, :sigma0_trip) == 6
    @test isnothing(MetopDatasets.get_scale_factor(MetopDatasets.ASCA_SZO_1B_V13,
        :record_header))
    @test MetopDatasets.get_dimensions(MetopDatasets.ASCA_SZO_1B_V13) ==
          Dict("num_band" => 3, "xtrack" => 42)

    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZF_1B_V13) == 4256
    @test test_dimensions(MetopDatasets.ASCA_SZF_1B_V13)
    @test MetopDatasets.get_scale_factor(MetopDatasets.ASCA_SZF_1B_V13, :inc_angle_full) ==
          2
    @test MetopDatasets.get_dimensions(MetopDatasets.ASCA_SZF_1B_V13) ==
          Dict("xtrack" => 192)

    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZF_1B_V12) == 3684
    @test test_dimensions(MetopDatasets.ASCA_SZF_1B_V12)
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZR_1B_V12) == 8153
    @test test_dimensions(MetopDatasets.ASCA_SZR_1B_V12)
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZO_1B_V12) == 4193
    @test test_dimensions(MetopDatasets.ASCA_SZO_1B_V12)

    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZF_1B_V11) == 41624
    @test test_dimensions(MetopDatasets.ASCA_SZF_1B_V11)
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZR_1B_V11) == 7818
    @test test_dimensions(MetopDatasets.ASCA_SZR_1B_V11)
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZO_1B_V11) == 4018
    @test test_dimensions(MetopDatasets.ASCA_SZO_1B_V11)

    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SMO_02_V12) == 6003
    @test test_dimensions(MetopDatasets.ASCA_SMO_02_V12)
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SMR_02_V12) == 11683
    @test test_dimensions(MetopDatasets.ASCA_SMR_02_V12)
end

function get_data_record_type(file)
    data_record_type = open(file, "r") do file_pointer
        main_header = MetopDatasets.native_read(
            file_pointer, MetopDatasets.MainProductHeader)
        return MetopDatasets.data_record_type(main_header)
    end
    return data_record_type
end

@testset "Test data_record_type" begin
    @test get_data_record_type(SZO_V13_test_file) == MetopDatasets.ASCA_SZO_1B_V13
    @test get_data_record_type(SZR_V13_test_file) == MetopDatasets.ASCA_SZR_1B_V13
    @test get_data_record_type(SZF_V13_test_file) == MetopDatasets.ASCA_SZF_1B_V13
end

@testset "SZR no dummy record" begin
    ds = MetopDataset(SZR_V13_test_file)

    # check the number of records
    total_count = parse(Int, ds.attrib["total_mdr"])
    data_count = ds.dim[MetopDatasets.RECORD_DIM_NAME]
    @test total_count == data_count

    # check that longitude and latitude are in the correct range
    longitude = Array(ds["longitude"])
    latitude = Array(ds["latitude"])

    @test all((0 .<= longitude) .& (longitude .<= 360))
    @test all((-90 .<= latitude) .& (latitude .<= 90))

    # test time stamps
    @test abs(DateTime(ds.attrib["sensing_start"]) - ds["utc_line_nodes"][1]) <
          Second(2)
    @test abs(DateTime(ds.attrib["sensing_end"]) - ds["utc_line_nodes"][end]) <
          Second(2)
end

@testset "SZO " begin
    ds = MetopDataset(SZO_V13_test_file)

    # check times to sample start and end of file.
    @test abs(DateTime(ds.attrib["sensing_start"]) - ds["utc_line_nodes"][1]) <
          Second(2)
    @test abs(DateTime(ds.attrib["sensing_end"]) - ds["utc_line_nodes"][end]) <
          Second(2)
end

@testset "SZF " begin
    ds = MetopDataset(SZF_V13_test_file)

    # check times to sample start and end of file.
    @test abs(DateTime(ds.attrib["sensing_start"]) - ds["utc_localisation"][1]) <
          Second(2)
    @test abs(DateTime(ds.attrib["sensing_end"]) - ds["utc_localisation"][end]) <
          Second(2)
end

@testset "SMR v12" begin
    ds = MetopDataset(SMR_V12_test_file)

    # check times to sample start and end of file.
    @test abs(DateTime(ds.attrib["sensing_start"]) - ds["utc_line_nodes"][1]) <
          Second(2)
    @test abs(DateTime(ds.attrib["sensing_end"]) - ds["utc_line_nodes"][end]) <
          Second(2)
end

@testset "SMO v12" begin
    ds = MetopDataset(SMO_V12_test_file)

    # check times to sample start and end of file.
    @test abs(DateTime(ds.attrib["sensing_start"]) - ds["utc_line_nodes"][1]) <
          Second(2)
    @test abs(DateTime(ds.attrib["sensing_end"]) - ds["utc_line_nodes"][end]) <
          Second(2)
end
