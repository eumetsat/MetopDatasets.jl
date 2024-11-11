# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test
using Dates

SZO_V13_test_file = "testData/ASCA_SZO_1B_M03_20230329063300Z_20230329063556Z_N_C_20230329081417Z"
SZR_V13_test_file = "testData/ASCA_SZR_1B_M03_20230329063300Z_20230329063558Z_N_C_20230329081417Z"
SZR_V12_test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"
SZF_V11_test_file = "testData/ASCA_SZF_1B_M02_20111207032400Z_20111207050859Z_N_O_20111207041515Z.nat"

SMO_V12_test_file = "testData/ASCA_SMO_02_M03_20231218101200Z_20231218101456Z_N_C_20231218115643Z"
SMR_V12_test_file = "testData/ASCA_SMR_02_M03_20231218101200Z_20231218101458Z_N_C_20231218115649Z"

# Product with dummy record and missing receive date. 
SZF_with_dummy_in_mid = "testData/ASCA_SZF_1B_M01_20221107123600Z_20221107141459Z_N_O_20221107132528Z.nat";

function test_dimensions(record_type)
    fields = fieldnames(record_type)
    return !isnothing(MetopDatasets.get_field_dimensions.(record_type, fields))
end

@testset "ASCAT data records types" begin
    ## ASCA_SZR_1B_V13
    @test MetopDatasets.ASCA_SZR_1B_V13 <: DataRecord
    @test MetopDatasets.native_sizeof(MetopDatasets.ASCA_SZR_1B_V13) == 6677
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

if isdir("testData") #TODO test data should be handle as an artifact or something similar.
    @testset "Test data_record_type" begin
        @test get_data_record_type(SZO_V13_test_file) == MetopDatasets.ASCA_SZO_1B_V13
        @test get_data_record_type(SZR_V13_test_file) == MetopDatasets.ASCA_SZR_1B_V13
        @test get_data_record_type(SZR_V12_test_file) == MetopDatasets.ASCA_SZR_1B_V12
    end
end

if isdir("testData") #TODO test data should be handle as an artifact or something similar.
    @testset "Read ASCAT as MetopProduct" begin
        @testset "SZF with dummy record" begin
            product = MetopProduct(SZF_with_dummy_in_mid)

            # check the number of records
            @test product.main_product_header.total_mdr ==
                  (length(product.data_records) + length(product.dummy_records))

            # check that longitude and latitude are in the correct range
            longitude = [rec.longitude_full for rec in product.data_records] ./
                        10^MetopDatasets.get_scale_factor(eltype(product.data_records),
                :longitude_full)
            latitude = [rec.latitude_full for rec in product.data_records] ./
                       10^MetopDatasets.get_scale_factor(eltype(product.data_records),
                :latitude_full)

            @test all([all((0 .<= arr) .& (arr .<= 360)) for arr in longitude])
            @test all([all((-90 .<= arr) .& (arr .<= 90)) for arr in latitude])

            # test time stamps
            time_stamp = DateTime.([rec.utc_localisation for rec in product.data_records])
            @test round(product.main_product_header.sensing_start, Second) ==
                  round(minimum(time_stamp), Second)
            @test round(product.main_product_header.sensing_end, Second) ==
                  round(maximum(time_stamp), Second)
        end

        @testset "SZR no dummy record" begin
            product = MetopProduct(SZR_V13_test_file)

            # check the number of records
            @test product.main_product_header.total_mdr == length(product.data_records)
            @test length(product.dummy_records) == 0

            # check that longitude and latitude are in the correct range
            longitude = [rec.longitude for rec in product.data_records] ./
                        10^MetopDatasets.get_scale_factor(eltype(product.data_records),
                :longitude)
            latitude = [rec.latitude for rec in product.data_records] ./
                       10^MetopDatasets.get_scale_factor(eltype(product.data_records),
                :latitude)

            @test all([all((0 .<= arr) .& (arr .<= 360)) for arr in longitude])
            @test all([all((-90 .<= arr) .& (arr .<= 90)) for arr in latitude])

            # test time stamps
            time_stamp = DateTime.([rec.utc_line_nodes for rec in product.data_records])
            @test round(product.main_product_header.sensing_start, Second) ==
                  round(minimum(time_stamp), Second)
            @test round(product.main_product_header.sensing_end, Second) ==
                  round(maximum(time_stamp), Second)
        end

        @testset "SZO " begin
            product = MetopProduct(SZO_V13_test_file)

            # check the number of records
            @test product.main_product_header.total_mdr == length(product.data_records)
            @test length(product.dummy_records) == 0
        end

        @testset "SZF v11" begin
            product = MetopProduct(SZF_V11_test_file)

            # Check read static array of RecordSubType
            record1 = product.data_records[1]
            times = DateTime.(record1.utc_localisation)
            @test all(round.(times, Minute) .== DateTime("2011-12-07T03:24"))
        end

        @testset "SMR v13" begin
            product = MetopProduct(SMR_V12_test_file)

            # Check read static array of RecordSubType
            record1 = product.data_records[1]
            @test DateTime(record1.utc_line_nodes) == DateTime("2023-12-18T10:12")
        end

        @testset "SMO v13" begin
            product = MetopProduct(SMO_V12_test_file)

            # Check read static array of RecordSubType
            record1 = product.data_records[1]
            @test DateTime(record1.utc_line_nodes) == DateTime("2023-12-18T10:12")
        end
    end
end
