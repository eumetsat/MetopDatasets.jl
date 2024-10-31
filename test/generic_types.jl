# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test

@testset "bitstring" begin
    @test MetopDatasets.native_sizeof(MetopDatasets.BitString{34}) == 34
    @test MetopDatasets.native_sizeof(MetopDatasets.BitString{2}) == 2
end

@testset "vinteger" begin
    @test MetopDatasets.native_sizeof(MetopDatasets.VInteger{UInt32}) == 5
    @test MetopDatasets.native_sizeof(MetopDatasets.VInteger{Int64}) == 9

    v1 = MetopDatasets.VInteger(Int8(4), UInt32(20))
    @test float(v1) ≈ 0.002 # TODO double check it is correct
end
