# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test
using Dates

# Helper function to create MetopDiskArray.
function _chunks(file_pointer)
    seekstart(file_pointer)
    main_product_header = MetopDatasets.native_read(file_pointer,
        MetopDatasets.MainProductHeader)

    MetopDatasets._skip_sphr(file_pointer, main_product_header.total_sphr)
    record_chunks, _ = MetopDatasets._read_record_chunks(file_pointer, main_product_header)
    return record_chunks
end

@testset "Disk array constructor" begin
    test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"

    #expected number of records 3264
    file_pointer = open(test_file, "r")
    record_chunks = _chunks(file_pointer)
    number_of_records = 3264

    utc_time = MetopDatasets.MetopDiskArray(
        file_pointer, record_chunks, :utc_line_nodes; auto_convert = false)
    @test utc_time isa MetopDatasets.MetopDiskArray{MetopDatasets.ShortCdsTime, 1}
    @test utc_time.field_type <: MetopDatasets.ShortCdsTime
    @test utc_time.record_count == number_of_records
    @test utc_time.offset_in_record == 22
    @test size(utc_time) == (number_of_records,)

    sigma0 = MetopDatasets.MetopDiskArray(file_pointer, record_chunks, :sigma0_trip)
    @test sigma0 isa MetopDatasets.MetopDiskArray{Int32, 3}
    @test sigma0.field_type <: Matrix{Int32}
    @test sigma0.record_count == number_of_records
    @test sigma0.offset_in_record == 773
    @test size(sigma0) == (3, 82, number_of_records)

    latitude = MetopDatasets.MetopDiskArray(file_pointer, record_chunks, :latitude)
    @test latitude isa MetopDatasets.MetopDiskArray{Int32, 2}
    @test latitude.field_type <: Vector{Int32}
    @test latitude.record_count == number_of_records
    @test latitude.offset_in_record == 117
    @test size(latitude) == (82, number_of_records)

    close(file_pointer)
end

@testset "Disk array get index" begin
    test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"

    #expected number of records 3264
    file_pointer = open(test_file, "r")
    record_chunks = _chunks(file_pointer)

    utc_time = MetopDatasets.MetopDiskArray(file_pointer, record_chunks, :utc_line_nodes;
        auto_convert = false)
    sigma0 = MetopDatasets.MetopDiskArray(file_pointer, record_chunks, :sigma0_trip)
    record_start_time = MetopDatasets.MetopDiskArray(
        file_pointer, record_chunks, :record_start_time)

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

@testset "Disk array compare with product" begin
    test_file = "testData/ASCA_SZF_1B_M01_20221107123600Z_20221107141459Z_N_O_20221107132528Z.nat" # with dummy records

    product = MetopProduct(test_file)

    #expected number of records 3264
    file_pointer = open(test_file, "r")
    record_chunks = _chunks(file_pointer)

    utc_time = MetopDatasets.MetopDiskArray(file_pointer, record_chunks, :utc_localisation)
    sigma0 = MetopDatasets.MetopDiskArray(file_pointer, record_chunks, :sigma0_full)

    utc_time_prod = [r.utc_localisation for r in product.data_records]
    sigma0_prod = reduce(hcat, [r.sigma0_full for r in product.data_records])

    @test utc_time[:] == MetopDatasets.seconds_since_epoch.(utc_time_prod[:])
    @test sigma0_prod[:, :] == sigma0_prod[:, :]

    close(file_pointer)
end
