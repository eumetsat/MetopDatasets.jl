# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, NCDatasets, Test

test_data_artifact = MetopDatasets.get_test_data_artifact()

@testset "ASCAT SZR to netCDF" begin
    test_file = joinpath(
        test_data_artifact, "ASCA_SZR_1B_M01_20241217081500Z_cropped_10.nat")
    ds_nat = MetopDataset(test_file)

    # convert file to netCDF
    @time netcdf_file = tempname(; cleanup = true)
    NCDataset(netcdf_file, "c") do ds_temp
        NCDatasets.write(ds_temp, ds_nat)
        return nothing
    end

    ds_nc = NCDataset(netcdf_file)
    sigma0_trip = Array(ds_nat["sigma0_trip"])
    no_data = ismissing.(sigma0_trip)

    @test Array(ds_nat["sigma0_trip"])[.!no_data] == Array(ds_nc["sigma0_trip"])[.!no_data]
    @test Array(ds_nat["utc_line_nodes"]) == Array(ds_nc["utc_line_nodes"])
    @test Array(ds_nat["latitude"]) == Array(ds_nc["latitude"])
    @test ds_nat.attrib["receive_time_end"] == ds_nc.attrib["receive_time_end"]
    @test ds_nat.attrib["semi_major_axis"] == ds_nc.attrib["semi_major_axis"]
    @test ds_nat.attrib["parent_product_name_1"] == ds_nc.attrib["parent_product_name_1"]

    close(ds_nat)
    close(ds_nc)
end

@testset "IASI L1 to netCDF" begin
    test_file = joinpath(
        test_data_artifact, "IASI_xxx_1C_M01_20240925202059Z_cropped_5.nat")
    netcdf_file = tempname(; cleanup = true)

    # convert file to netCDF
    @time MetopDataset(test_file) do ds_nat
        NCDataset(netcdf_file, "c") do ds_temp
            NCDatasets.write(ds_temp, ds_nat)
            return nothing
        end
    end

    ds_nat = MetopDataset(test_file)
    ds_nc = NCDataset(netcdf_file)

    @test Array(ds_nat["ggeosondloc"]) == Array(ds_nc["ggeosondloc"])
    @test Array(ds_nat["gs1cspect"]) == Array(ds_nc["gs1cspect"])
    @test ds_nat.attrib["receive_time_end"] == ds_nc.attrib["receive_time_end"]
    @test ds_nat.attrib["semi_major_axis"] == ds_nc.attrib["semi_major_axis"]
    @test ds_nat.attrib["parent_product_name_1"] == ds_nc.attrib["parent_product_name_1"]

    close(ds_nat)
    close(ds_nc)
end

@testset "IASI L2 to netCDF" begin
    test_file = joinpath(
        test_data_artifact, "IASI_SND_02_M03_20250120105357Z_cropped_10.nat")
    netcdf_file = tempname(; cleanup = true)

    # convert file to netCDF
    @time MetopDataset(test_file) do ds_nat
        NCDataset(netcdf_file, "c") do ds_temp
            NCDatasets.write(ds_temp, ds_nat)
            return nothing
        end
    end

    ds_nat = MetopDataset(test_file)
    ds_nc = NCDataset(netcdf_file)

    @test !isnothing(ds_nc)

    close(ds_nat)
    close(ds_nc)
end

@testset "MHS L1B to netCDF" begin
    test_file = joinpath(
        test_data_artifact, "MHSx_xxx_1B_M03_20250915084851Z_cropped_10.nat")
    netcdf_file = tempname(; cleanup = true)

    # convert file to netCDF
    @time MetopDataset(test_file) do ds_nat
        NCDataset(netcdf_file, "c") do ds_temp
            NCDatasets.write(ds_temp, ds_nat)
            return nothing
        end
    end

    ds_nat = MetopDataset(test_file)
    ds_nc = NCDataset(netcdf_file)

    @test !isnothing(ds_nc)

    close(ds_nat)
    close(ds_nc)
end
