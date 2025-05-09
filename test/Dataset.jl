# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test
import CommonDataModel as CDM
using Dates

test_data_artifact = joinpath("../reduced_data", "reduced_data")

@testset "MetopDataset basics" begin
    test_file = joinpath(
        test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")

    ds = MetopDataset(test_file)

    # test all dimensions are valid
    @test MetopDatasets._valid_dimensions(ds)

    @test ds isa MetopDataset{MetopDatasets.ASCA_SZR_1B_V13}
    @test keys(ds) == (
        "record_start_time", "record_stop_time", "degraded_inst_mdr", "degraded_proc_mdr",
        "utc_line_nodes", "abs_line_number", "sat_track_azi", "as_des_pass",
        "swath_indicator", "latitude", "longitude", "sigma0_trip", "kp", "inc_angle_trip",
        "azi_angle_trip", "num_val_trip", "f_kp", "f_usable", "f_land", "lcr", "flagfield")

    @test CDM.dimnames(ds) == ["num_band", "xtrack", "atrack"]
    @test CDM.dim(ds, :xtrack) == 82
    @test CDM.dim(ds, "atrack") == ds.main_product_header.total_mdr
    @test !isnothing(CDM.attribnames(ds))
    @test CDM.attrib(ds, "sensing_start") == string(DateTime("2024-12-17T08:15:00"))
    close(ds)
end

@testset "MetopDataset variables" begin
    test_file = joinpath(
        test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")
    ds = MetopDataset(test_file)

    sigma_var = CDM.variable(ds, :sigma0_trip)
    @test sigma_var isa MetopDatasets.MetopVariable
    a = sigma_var[:, 1:4, 1:2:6]
    @test a isa Array{Int32, 3}
    @test CDM.name(sigma_var) == "sigma0_trip"
    @test CDM.dimnames(sigma_var) == ["num_band", "xtrack", "atrack"]
    @test CDM.dataset(sigma_var) isa MetopDataset
    @test !isnothing(CDM.attrib(sigma_var, "description"))
    @test size(sigma_var) == (3, 82, 10)

    start_time_var = CDM.variable(ds, :record_start_time)
    @test start_time_var isa MetopDatasets.MetopVariable
    @test start_time_var[1:3] isa Vector{Float64}
    @test CDM.name(start_time_var) == "record_start_time"
    @test CDM.dimnames(start_time_var) == ["atrack"]
    @test !isnothing(CDM.attrib(start_time_var, "description"))
    @test size(start_time_var) == (10,)

    latitude = ds["latitude"]
    @test latitude isa CDM.CFVariable
    lats = latitude[:, :]
    @test lats isa Array{Union{Missing, Float64}, 2}
    @test all(-90 .< lats .< 90)

    num_val_trip = ds["num_val_trip"]
    @test num_val_trip isa CDM.AbstractVariable
    num_vals = num_val_trip[1:4]
    @test num_vals isa Vector{Union{Missing, UInt32}}
    @test all(num_vals .== [81, 96, 73, 73])

    times = ds["utc_line_nodes"][1:2:5]
    @test times isa Array{DateTime, 1}
    @test times == [
        DateTime("2024-12-17T08:15:00"),
        DateTime("2024-12-17T08:15:03.750"),
        DateTime("2024-12-17T08:15:07.500")
    ]

    # get single index test
    @test !isnothing(ds["utc_line_nodes"][2])

    close(ds)
end

@testset "MetopDataset auto_convert=false" begin
    test_file = joinpath(
        test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")
    ds = MetopDataset(test_file, auto_convert = false)

    times = ds["utc_line_nodes"][1:2:5]
    @test times isa Array{MetopDatasets.ShortCdsTime, 1}
    @test DateTime.(times) == [
        DateTime("2024-12-17T08:15:00"),
        DateTime("2024-12-17T08:15:03.750"),
        DateTime("2024-12-17T08:15:07.500")
    ]

    @test ds["record_start_time"][1:2:5] isa Array{MetopDatasets.ShortCdsTime, 1}

    close(ds)
end

@testset "MetopDataset read_first_record" begin
    test_file = joinpath(
        test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")
    ds = MetopDataset(test_file, auto_convert = false)

    mphr = MetopDatasets.read_first_record(ds, MetopDatasets.MainProductHeader)
    @test mphr isa MetopDatasets.MainProductHeader
    ipr = MetopDatasets.read_first_record(ds, MetopDatasets.InternalPointerRecord)
    @test ipr isa MetopDatasets.InternalPointerRecord
    mdr = MetopDatasets.read_first_record(ds, MetopDatasets.ASCA_SZR_1B_V13)
    @test mdr isa MetopDatasets.ASCA_SZR_1B_V13

    # read directly from file
    mphr2 = MetopDatasets.read_first_record(test_file, MetopDatasets.MainProductHeader)
    @test mphr2 isa MetopDatasets.MainProductHeader

    close(ds)
end
