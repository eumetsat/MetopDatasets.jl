# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test
import CommonDataModel as CDM

@testset "IASI data records" begin
    @test MetopDatasets.IASI_XXX_1C_V11 <: MetopDatasets.DataRecord
    @test MetopDatasets.native_sizeof(MetopDatasets.IASI_XXX_1C_V11) == 2728908
    @test MetopDatasets.get_scale_factor(MetopDatasets.IASI_XXX_1C_V11, :ggeosondloc) == 6
    field_index = findfirst(fieldnames(MetopDatasets.IASI_XXX_1C_V11) .== :gs1cspect)
    @test field_index == 40

    field_index = findfirst(fieldnames(MetopDatasets.IASI_XXX_1C_V11) .== :gqisflagqual)
    @test field_index == 21

    all_dims = [MetopDatasets.get_field_dimensions(MetopDatasets.IASI_XXX_1C_V11, x)
                for x in fieldnames(MetopDatasets.IASI_XXX_1C_V11)]
    @test !isempty(all_dims)

    @test MetopDatasets.native_sizeof(MetopDatasets.GIADR_IASI_XXX_1C_V11) == 84

    ## testData
    if isdir("testData")
        test_file = "testData/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"
        ds = MetopDataset(test_file)

        # test all dimensions are valid
        @test MetopDatasets._valid_dimensions(ds)

        # test GIADR
        giadr = MetopDatasets.read_first_record(ds, MetopDatasets.GIADR_IASI_XXX_1C_V11)
        @test giadr.idefscalesondnsfirst ==
              Int16[2581, 5921, 9009, 9541, 10721, 0, 0, 0, 0, 0]
        @test giadr.idefscalesondnslast ==
              Int16[5920, 9008, 9540, 10720, 11041, 0, 0, 0, 0, 0]
        @test giadr.idefscalesondscalefactor == Int16[7, 8, 9, 8, 9, 0, 0, 0, 0, 0]

        @test MetopDatasets.max_giadr_channel(giadr) == 8461

        @test MetopDatasets.get_channel_scale_factor(giadr, 1) == 7
        @test MetopDatasets.get_channel_scale_factor(giadr, 3340) == 7
        @test MetopDatasets.get_channel_scale_factor(giadr, 3341) == 8
        @test MetopDatasets.get_channel_scale_factor(giadr, 6428) == 8
        @test MetopDatasets.get_channel_scale_factor(giadr, 6429) == 9
        @test MetopDatasets.get_channel_scale_factor(giadr, 8461) == 9
        @test_throws "Channel 0 scale factor not found" MetopDatasets.get_channel_scale_factor(
            giadr, 0)
        @test_throws "Channel 8462 scale factor not found" MetopDatasets.get_channel_scale_factor(
            giadr, 8462)

        @test log10(ds["gircimage"].attrib["scale_factor"]) ≈ -giadr.idefscaleiisscalefactor

        # test radiance in CO2 Q branch (spectral index 92)
        l1c_spectra = ds["gs1cspect"]
        @test l1c_spectra[92, 1, 1, 1]≈0.0006165 atol=2e-5
        @test l1c_spectra[92, 1, 1, 1] isa Float32

        l1c_wave_number = ds["spectra_wave_number"]
        # test wavelength of CO2 Q (spectral index 92) should be 15 microns
        @test all((1 ./ l1c_wave_number[92, :]) .≈ 14.97566454511419e-6)
        @test l1c_wave_number[1, 1] isa Float64
        @test CDM.dimnames(l1c_wave_number) == ["spectral", "atrack"]

        # test that channels with no scaling is 0
        @test all(l1c_spectra[8462:end, 1:3, 1, 4] .== 0)

        # test variables
        first_lines = ds["gccsimageclassifiedfirstlin"][:, :]
        @test !isempty(first_lines)
        @test !isempty(float.(first_lines)) # TODO test if values are correct

        #test bit strings
        onboard_time = ds["obt"][:, :]
        @test !isempty(onboard_time)
        @test any(onboard_time .!= 0)# check that there is non zero values

        @test ds["ggeosondloc"][1, 1, 1, 1]≈156 atol=1 # test first longitude in file
        @test ds["ggeosondloc"][2, 1, 1, 1]≈-52 atol=1 # test first latitude in file

        @test sort(CDM.dimnames(ds)) ==
              ["atrack", "avhrr_channel", "avhrr_image_column", "avhrr_image_line", "band",
            "corner_cube_direction", "eigenvalue", "fov_class",
            "integrated_imager_column", "integrated_imager_line",
            "line_column", "lon_lat", "sounder_pixel", "spectral",
            "subgrid_imager_pixel", "xtrack", "zenith_azimuth"]
        @test CDM.dim(ds, :spectral) == 8700
        @test CDM.dim(ds, "atrack") == ds.main_product_header.total_mdr

        # test VInteger
        @test ds["gepslociasiavhrr_iasi"][1:5] isa Array{Float64, 1}

        close(ds)

        # test high_precision = true
        ds_high = MetopDataset(test_file, high_precision = true)
        l1c_spectra = ds_high["gs1cspect"]
        @test l1c_spectra[92, 1, 1, 1]≈0.0006165 atol=2e-5
        @test l1c_spectra[92, 1, 1, 1] isa Float64
        close(ds_high)
    end
end

@testset "IASI auto_convert=false" begin
    if isdir("testData")
        test_file = "testData/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"
        ds = MetopDataset(test_file, auto_convert = false)

        @test ds["obt"][1:5] isa Array{MetopDatasets.BitString{6}, 1}
        @test ds["gepslociasiavhrr_iasi"][1:5] isa Array{MetopDatasets.VInteger{Int32}, 1}

        giadr = MetopDatasets.read_first_record(ds, MetopDatasets.GIADR_IASI_XXX_1C_V11)

        ## The gircimage should still have a scale_factor.
        @test log10(ds["gircimage"].attrib["scale_factor"]) ≈ -giadr.idefscaleiisscalefactor

        selected_spectra = ds["gs1cspect"][:, 1:2, 1:2, 1]
        @test selected_spectra isa Array{Int16}

        #test manuel scaling of spectrum
        scaled_spectra = MetopDatasets.scale_iasi_spectrum(selected_spectra, giadr)
        @test scaled_spectra[92, 1, 1]≈0.0006165 atol=2e-5

        # spectra_wave_number is only computed for auto_convert = true
        @test !("spectra_wave_number" in keys(ds))

        close(ds)
    end
end
