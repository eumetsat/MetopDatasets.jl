# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopNative, Test

@testset "bitstring" begin
    @test MetopNative.native_sizeof(MetopNative.BitString{34}) == 34
    @test MetopNative.native_sizeof(MetopNative.BitString{2}) == 2
end

@testset "vinteger" begin
    @test MetopNative.native_sizeof(MetopNative.VInteger{UInt32}) == 5
    @test MetopNative.native_sizeof(MetopNative.VInteger{Int64}) == 9

    v1 = MetopNative.VInteger(Int8(4), UInt32(20))
    @test float(v1) ≈ 0.002 # TODO double check it is correct
end
