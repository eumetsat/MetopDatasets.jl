# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test

@testset "Data chunk without dummy" begin
    # extracted from "test/testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat";
    total_size = 26618899
    data_record_type = MetopDatasets.ASCA_SZR_1B_V12
    data_record_size = MetopDatasets.native_sizeof(data_record_type)

    pointers = [MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x1b24, 0x02c75d60),
                        MetopDatasets.ShortCdsTime(0x1b24, 0x0324b84d)),
                    0x06,
                    0x02,
                    0x05,
                    0x00001b5c)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x1b24, 0x02c75d60),
                        MetopDatasets.ShortCdsTime(0x1b24, 0x0324b84d)),
                    0x06,
                    0x02,
                    0x06,
                    0x00001bd4)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x1b24, 0x02c75d60),
                        MetopDatasets.ShortCdsTime(0x1b24, 0x0324b84d)),
                    0x07,
                    0x02,
                    0x04,
                    0x00001c4c)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x1b24, 0x02c75d60),
                        MetopDatasets.ShortCdsTime(0x1b24, 0x0324b84d)),
                    0x07,
                    0x02,
                    0x06,
                    0x00001d34)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x1b24, 0x02c75d60),
                        MetopDatasets.ShortCdsTime(0x1b24, 0x0324b84d)),
                    0x08,
                    0x02,
                    0x01,
                    0x00001d53)]

    record_chunks = MetopDatasets.get_data_record_chunks(pointers,
        total_size,
        data_record_type)

    datarecord_chunks = filter(x -> x.record_type != MetopDatasets.DummyRecord, record_chunks)
    dummyrecord_chunks = filter(x -> x.record_type == MetopDatasets.DummyRecord,
        record_chunks)

    @test length(datarecord_chunks) == 1
    @test length(dummyrecord_chunks) == 0

    @test length(datarecord_chunks[1].record_range) == 3264
    @test datarecord_chunks[1].record_range[1] == 1

    size_of_records = data_record_size * length(datarecord_chunks[1].record_range)
    @test total_size == datarecord_chunks[1].offset + size_of_records
end

@testset "Data chunk with dummy" begin
    # extracted from "test/testData/ASCA_SZF_1B_M01_20221107123600Z_20221107141459Z_N_O_20221107132528Z.nat";
    total_size = 152637391
    data_record_type = MetopDatasets.ASCA_SZF_1B_V12
    data_record_size = MetopDatasets.native_sizeof(data_record_type)

    pointers = [MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x209a, 0x02b424a0),
                        MetopDatasets.ShortCdsTime(0x209a, 0x030ec404)),
                    0x07,
                    0x02,
                    0x06,
                    0x00001d85)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x209a, 0x02b424a0),
                        MetopDatasets.ShortCdsTime(0x209a, 0x030ec404)),
                    0x07,
                    0x02,
                    0x08,
                    0x00001da4)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x209a, 0x02b424a0),
                        MetopDatasets.ShortCdsTime(0x209a, 0x030ec404)),
                    0x08,
                    0x02,
                    0x03,
                    0x007c6da4)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x209a, 0x02b424a0),
                        MetopDatasets.ShortCdsTime(0x209a, 0x030ec404)),
                    0x08,
                    0x0d,
                    0x01,
                    0x08170a98)
                MetopDatasets.InternalPointerRecord(
                    MetopDatasets.RecordHeader(0x03,
                        0x00,
                        0x00,
                        0x01,
                        0x0000001b,
                        MetopDatasets.ShortCdsTime(0x209a, 0x02b424a0),
                        MetopDatasets.ShortCdsTime(0x209a, 0x030ec404)),
                    0x08,
                    0x02,
                    0x03,
                    0x08170ad7)]

    record_chunks = MetopDatasets.get_data_record_chunks(pointers,
        total_size,
        data_record_type)

    datarecord_chunks = filter(x -> x.record_type != MetopDatasets.DummyRecord, record_chunks)
    dummyrecord_chunks = filter(x -> x.record_type == MetopDatasets.DummyRecord,
        record_chunks)

    @test length(datarecord_chunks) == 2
    @test length(dummyrecord_chunks) == 1

    @test datarecord_chunks[1].record_range[1] == 1
    @test (datarecord_chunks[1].record_range[end] + 1) ==
          datarecord_chunks[2].record_range[1]

    size_chunk_1 = data_record_size * length(datarecord_chunks[1].record_range)
    size_chunk_2 = MetopDatasets.native_sizeof(MetopDatasets.DummyRecord) *
                   length(dummyrecord_chunks[1].record_range)
    size_chunk_3 = data_record_size * length(datarecord_chunks[2].record_range)

    @test (size_chunk_1 + datarecord_chunks[1].offset) == dummyrecord_chunks[1].offset
    @test (size_chunk_2 + dummyrecord_chunks[1].offset) == datarecord_chunks[2].offset
    @test (size_chunk_3 + datarecord_chunks[2].offset) == total_size
end
