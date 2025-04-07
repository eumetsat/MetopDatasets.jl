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

@testset "Disk array constructor" begin
    test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"

    #expected number of records 3264
    file_pointer = open(test_file, "r")
    record_layouts = _layouts(file_pointer)
    number_of_records = 3264

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
    test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"

    #expected number of records 3264
    file_pointer = open(test_file, "r")
    record_layouts = _layouts(file_pointer)

    utc_time = MetopDatasets.MetopDiskArray(file_pointer, record_layouts, :utc_line_nodes;
        auto_convert = false)
    sigma0 = MetopDatasets.MetopDiskArray(file_pointer, record_layouts, :sigma0_trip)
    record_start_time = MetopDatasets.MetopDiskArray(
        file_pointer, record_layouts, :record_start_time)

    @test !isnothing(utc_time[7])
    @test !isnothing(utc_time[1:60])
    @test !isnothing(utc_time[1:4:60])
    @test !isnothing(utc_time[:])
    @test utc_time[1:60] isa Vector{MetopDatasets.ShortCdsTime}
    compare_times = DateTime.(utc_time[1:2:5]) .== [
        DateTime("2019-01-09T12:56:59.999"),
        DateTime("2019-01-09T12:57:03.750"),
        DateTime("2019-01-09T12:57:07.500")
    ]
    @test all(compare_times)

    @test !isnothing(sigma0[1:60])
    @test !isnothing(sigma0[1:4:60])
    @test !isnothing(sigma0[1, 2, 4])
    @test !isnothing(sigma0[1, 1:8, 30:2:(end - 1)])

    @test !isnothing(record_start_time[4:9])

    close(file_pointer)
end
