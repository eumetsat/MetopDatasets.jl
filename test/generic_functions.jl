# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test

struct TestRecord <: MetopDatasets.DataRecord
    f1::Array{Int16, 3}
    f2::Array{MetopDatasets.ShortCdsTime, 4}
    f3::Int64
end

# around 2 MB array
f1_array_size = (100, 101, 102)
f2_array_size = (10, 11, 12, 13)
f3_array_size = (1, 1, 1, 1)

function MetopDatasets.get_raw_format_dim(T::Type{TestRecord})
    return Dict(:f1 => (f1_array_size..., 1),
        :f2 => f2_array_size,
        :f3 => f3_array_size)
end

MetopDatasets.fixed_size(T::Type{TestRecord}) = true

@testset "native_read" begin
    @test MetopDatasets.get_raw_format_dim(TestRecord)[:f1] == (100, 101, 102, 1)
    @test MetopDatasets._get_array_size(TestRecord, :f1) == f1_array_size
    @test MetopDatasets._get_array_length(TestRecord, :f1) == prod(f1_array_size)

    # create a temp file
    f1_test_array = rand(Int16, f1_array_size)
    f2_test_element = MetopDatasets.ShortCdsTime(UInt16(34), UInt32(1023))
    f3_test = Int64(-2334)

    test_record = mktemp() do path, io
        # write f1_test_array to test file
        [write(io, hton(elem)) for elem in f1_test_array]

        # write f2_test_array to test file
        for _ in 1:prod(f2_array_size)
            write(io, hton(f2_test_element.day))
            write(io, hton(f2_test_element.millisecond))
        end

        write(io, hton(Int(f3_test)))

        # read the record from the temp file
        seekstart(io)
        return MetopDatasets.native_read(io, TestRecord)
    end

    # test that the record is read correct.
    @test all(test_record.f1 .== f1_test_array)
    @test all([elem == f2_test_element for elem in test_record.f2])
    @test test_record.f3 == f3_test
end
