# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test, Dates

test_data_artifact = MetopDatasets.get_test_data_artifact()

@testset "Read header" begin
    test_files = joinpath(
        test_data_artifact, "ASCA_SZO_1B_M03_20250504214500Z_cropped_10.nat")

    main_header,
    bytes_read = open(test_files, "r") do file_pointer
        main_header = MetopDatasets.native_read(
            file_pointer, MetopDatasets.MainProductHeader)
        return main_header, position(file_pointer)
    end

    @test bytes_read == 3307

    # test record header
    record_header = main_header.record_header
    @test record_header.record_class ==
          MetopDatasets.get_record_class(MetopDatasets.MainProductHeader)
    @test record_header.record_size == 3307
    years_since_2000 = floor(Int64, record_header.record_start_time.day / 365.25)
    @test years_since_2000 == 25

    # test main product header
    @test main_header isa MetopDatasets.MainProductHeader
    @test main_header.processing_centre == "CGS1"
    @test main_header.format_major_version == 13
    @test main_header.subsetted_product == "F"
    @test main_header.sensing_start == DateTime("2025-05-04T21:45:00")

    # test data_record_type 
    @test MetopDatasets.data_record_type(main_header) == MetopDatasets.ASCA_SZO_1B_V13
end
