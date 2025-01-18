# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, NCDatasets, Test

# move attributes to be part of netcdf
@testset "ASCAT SZF to netCDF" begin
    test_file = "testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"
    ds_nat = MetopDataset(test_file)

    # convert file to netCDF
    @info "convert ASCAT SZF file, size: $(round(filesize(test_file)/10^6, digits=2)) Mb"
    # (Lupemba PC) Speed is roughly 27 Mb in 1 ms + 9 ms compilation, data rate ~ 27 Gb/s
    @time netcdf_file = tempname(; cleanup = true)
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
    size_factor_ASCAT_L1 = filesize(netcdf_file) / filesize(test_file)
    @show size_factor_ASCAT_L1
    @test size_factor_ASCAT_L1 < 1.2
end

# move attributes to be part of netcdf
@testset "IASI L1 to netCDF" begin
    test_file = "testData/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"
    netcdf_file = tempname(; cleanup = true)

    # convert file to netCDF
    @info "convert IASI L1 file, size: $(round(filesize(test_file)/10^6, digits=2)) Mb"
    # (Lupemba PC) Speed is roughly 60 Mb in 1.5s + 29.5s compilation, data rate ~ 40Mb/s
    @time MetopDataset(test_file) do ds_nat
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
    size_factor_IASI_L1 = filesize(netcdf_file) / filesize(test_file)
    @show size_factor_IASI_L1
    @test size_factor_IASI_L1 < 2.0
end

@testset "IASI L2 to netCDF" begin
    test_file = "testData/IASI_SND_02_M01_20241215173256Z_20241215173552Z_N_C_20241215182326Z"
    netcdf_file = tempname(; cleanup = true)

    # convert file to netCDF
    # (Lupemba PC) Speed is roughly 24 Mb in 30s + 10s compilation, data rate ~1Mb/s
    @info "convert IASI L2 file, size: $(round(filesize(test_file)/10^6, digits=2)) Mb"
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

    size_factor_IASI_L2 = filesize(netcdf_file) / filesize(test_file)
    @show size_factor_IASI_L2
    @test size_factor_IASI_L2 < 2.0
end
