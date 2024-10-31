# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test

eval(MetopDatasets.record_struct_expression(
    joinpath(@__DIR__, "TEST_FORmaT.csv"), DataRecord))
eval(MetopDatasets.record_struct_expression(
    joinpath(@__DIR__, "TEST_FORMAT2.csv"), DataRecord))

@testset "generate structs" begin
    @test TEST_FORMAT <: DataRecord
    @test TEST_FORMAT <: Record

    expected_fields = [:record_header, :degraded_inst_mdr, :degraded_proc_mdr,
        :utc_line_nodes,
        :abs_line_number, :sat_track_azi, :as_des_pass, :swath_indicator, :latitude,
        :longitude,
        :sigma0_trip, :kp, :inc_angle_trip, :azi_angle_trip, :num_val_trip,
        :f_kp, :f_usable, :f_land, :lcr, :flagfield]

    expected_types = [
        MetopDatasets.RecordHeader, UInt8, UInt8, MetopDatasets.ShortCdsTime,
        Int32, UInt16, UInt8,
        Vector{UInt8}, Vector{Int32}, Vector{Int32},
        Matrix{Int32}, Matrix{UInt16}, Matrix{UInt16},
        Matrix{Int16}, Matrix{UInt32}, Matrix{UInt8},
        Matrix{UInt8}, Matrix{UInt16}, Matrix{UInt16},
        Matrix{UInt32}]

    @test all(fieldnames(TEST_FORMAT) .== expected_fields)
    @test all(fieldtypes(TEST_FORMAT) .== expected_types)

    @test MetopDatasets.native_sizeof(TEST_FORMAT) == 6677

    # test fallback functions for dimensions
    @test MetopDatasets.get_dimensions(TEST_FORMAT) == Dict("dim_1" => 3, "dim_2" => 82)
    @test MetopDatasets.get_field_dimensions(TEST_FORMAT, :sigma0_trip) == ["dim_1", "dim_2"]
    @test MetopDatasets.get_field_dimensions(TEST_FORMAT, :latitude) == ["dim_2"]
    @test MetopDatasets.get_field_dimensions(TEST_FORMAT, :utc_line_nodes) == String[]

    # test a format with deleted rows
    @test all(fieldnames(TEST_FORMAT2) .== [:record_header, :degraded_inst_mdr,
        :degraded_proc_mdr, :utc_line_nodes, :abs_line_number,
        :sat_track_azi, :as_des_pass, :swath_indicator, :latitude, :longitude, :sigma0_trip,
        :kp, :inc_angle_trip,
        :azi_angle_trip, :num_val_trip, :f_kp, :f_usable, :f_f, :f_v, :f_oa, :f_sa, :f_tel,
        :f_ref, :f_land])
end
