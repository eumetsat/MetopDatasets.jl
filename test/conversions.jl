# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, NCDatasets, Test

# move attributes to be part of netcdf
@testset "ASCAT SZF to netCDF" begin
    test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"
    ds_nat = MetopDataset(test_file)

    # convert file to netCDF
    netcdf_file = tempname(; cleanup = true)
    NCDataset(netcdf_file, "c") do ds_temp
        NCDatasets.write(ds_temp, ds_nat)
        return nothing
    end

    ds_nc = NCDataset(netcdf_file)

    @test all(Array(ds_nat["sigma0_trip"]) .== Array(ds_nc["sigma0_trip"]))
    @test all(Array(ds_nat["utc_line_nodes"]) .== Array(ds_nc["utc_line_nodes"]))
    @test all(Array(ds_nat["latitude"]) .== Array(ds_nc["latitude"]))
    @test ds_nat.attrib["receive_time_end"] .== ds_nc.attrib["receive_time_end"]
    @test ds_nat.attrib["semi_major_axis"] .== ds_nc.attrib["semi_major_axis"]
    @test ds_nat.attrib["parent_product_name_1"] .== ds_nc.attrib["parent_product_name_1"]

    close(ds_nat)
    close(ds_nc)

    # check that increase in filesize is under 20 %
    #@show filesize(netcdf_file) / filesize(test_file)
    @test filesize(netcdf_file) / filesize(test_file) < 1.2
end

# move attributes to be part of netcdf
@testset "IASI to netCDF" begin
    test_file = "testData/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"
    netcdf_file = tempname(; cleanup = true)

    # convert file to netCDF
    # TODO fix warnings. DiskArrays gives a warning because BitString is converted to a string and strings
    # are not a Base.isbitstype()
    MetopDataset(test_file) do ds_nat
        NCDataset(netcdf_file, "c") do ds_temp
            NCDatasets.write(ds_temp, ds_nat)
            return nothing
        end
    end

    ds_nat = MetopDataset(test_file)
    ds_nc = NCDataset(netcdf_file)

    @test all(Array(ds_nat["ggeosondloc"]) .== Array(ds_nc["ggeosondloc"]))
    @test all(Array(ds_nat["gs1cspect"]) .== Array(ds_nc["gs1cspect"]))
    @test ds_nat.attrib["receive_time_end"] .== ds_nc.attrib["receive_time_end"]
    @test ds_nat.attrib["semi_major_axis"] .== ds_nc.attrib["semi_major_axis"]
    @test ds_nat.attrib["parent_product_name_1"] .== ds_nc.attrib["parent_product_name_1"]

    close(ds_nat)
    close(ds_nc)

    # check that increase in filesize is under 100 %
    # IASI file around 80 % due to the scaling of "gs1cspect" to Float32
    #@show filesize(netcdf_file) / filesize(test_file)
    @test filesize(netcdf_file) / filesize(test_file) < 2.0
end
