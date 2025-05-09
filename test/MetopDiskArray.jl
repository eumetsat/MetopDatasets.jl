# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test
using Dates

# Helper function to create MetopDiskArray.
function _layouts(file_pointer)
    seekstart(file_pointer)
    main_product_header = MetopDatasets.native_read(file_pointer,
        MetopDatasets.MainProductHeader)

    MetopDatasets._skip_sphr(file_pointer, main_product_header.total_sphr)
    record_layouts = MetopDatasets.read_record_layouts(file_pointer, main_product_header)
    return record_layouts
end

test_data_artifact = joinpath("../reduced_data", "reduced_data")

@testset "Disk array constructor" begin
    test_file = joinpath(
        test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")

    file_pointer = open(test_file, "r")
    record_layouts = _layouts(file_pointer)
    number_of_records = 10

    utc_time = MetopDatasets.MetopDiskArray(
        file_pointer, record_layouts, :utc_line_nodes; auto_convert = false)
    @test utc_time isa MetopDatasets.MetopDiskArray{MetopDatasets.ShortCdsTime, 1}
    @test utc_time.field_type <: MetopDatasets.ShortCdsTime
    @test size(utc_time)[end] == number_of_records
    @test utc_time.offsets_in_file[1] - record_layouts[1].offset == 22
    @test size(utc_time) == (number_of_records,)

    sigma0 = MetopDatasets.MetopDiskArray(file_pointer, record_layouts, :sigma0_trip)
    @test sigma0 isa MetopDatasets.MetopDiskArray{Int32, 3}
    @test sigma0.field_type <: Matrix{Int32}
    @test size(sigma0)[end] == number_of_records
    @test sigma0.offsets_in_file[1] - record_layouts[1].offset == 773
    @test size(sigma0) == (3, 82, number_of_records)

    latitude = MetopDatasets.MetopDiskArray(file_pointer, record_layouts, :latitude)
    @test latitude isa MetopDatasets.MetopDiskArray{Int32, 2}
    @test latitude.field_type <: Vector{Int32}
    @test size(latitude)[end] == number_of_records
    @test latitude.offsets_in_file[1] - record_layouts[1].offset == 117
    @test size(latitude) == (82, number_of_records)

    close(file_pointer)
end

@testset "Disk array get index" begin
    test_file = joinpath(
        test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")

    #expected number of records 3264
    file_pointer = open(test_file, "r")
    record_layouts = _layouts(file_pointer)

    utc_time = MetopDatasets.MetopDiskArray(file_pointer, record_layouts, :utc_line_nodes;
        auto_convert = false)
    sigma0 = MetopDatasets.MetopDiskArray(file_pointer, record_layouts, :sigma0_trip)
    record_start_time = MetopDatasets.MetopDiskArray(
        file_pointer, record_layouts, :record_start_time)

    @test !isnothing(utc_time[2])
    @test !isnothing(utc_time[2:9])
    @test !isnothing(utc_time[2:2:10])
    @test !isnothing(utc_time[:])
    @test utc_time[1:10] isa Vector{MetopDatasets.ShortCdsTime}
    compare_times = DateTime.(utc_time[1:2:5]) .== [
        DateTime("2024-12-17T08:15:00"),
        DateTime("2024-12-17T08:15:03.750"),
        DateTime("2024-12-17T08:15:07.500")
    ]
    @test all(compare_times)

    @test !isnothing(sigma0[1:10])
    @test !isnothing(sigma0[1:4:10])
    @test !isnothing(sigma0[1, 2, 4])
    @test !isnothing(sigma0[1, 1:8, 2:2:(end - 1)])

    @test !isnothing(record_start_time[4:9])

    close(file_pointer)
end
