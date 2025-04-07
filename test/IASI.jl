# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets, Test
import CommonDataModel as CDM

@testset "IASI L1C data records" begin
    @test MetopDatasets.IASI_XXX_1C_V11 <: MetopDatasets.DataRecord
    @test MetopDatasets.fixed_size(MetopDatasets.IASI_XXX_1C_V11) == true
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
    @test MetopDatasets.fixed_size(MetopDatasets.GIADR_IASI_XXX_1C_V11) == true

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

        l1c_wavenumber = ds["spectra_wavenumber"]
        # test wavelength of CO2 Q (spectral index 92) should be 15 microns
        @test all((1 ./ l1c_wavenumber[92, :]) .≈ 14.97566454511419e-6)
        @test l1c_wavenumber[1, 1] isa Float64
        @test CDM.dimnames(l1c_wavenumber) == ["spectral", "atrack"]

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
        @test selected_spectra isa Array{Union{Missing, Int16}}

        #test manuel scaling of spectrum
        scaled_spectra = MetopDatasets.scale_iasi_spectrum(selected_spectra, giadr)
        @test scaled_spectra[92, 1, 1]≈0.0006165 atol=2e-5

        # spectra_wavenumber is only computed for auto_convert = true
        @test !("spectra_wavenumber" in keys(ds))

        close(ds)
    end
end

@testset "IASI L02 V11 data records" begin
    @test MetopDatasets.fixed_size(MetopDatasets.IASI_SND_02_V11) == false

    # giard
    @test MetopDatasets.fixed_size(MetopDatasets.GIADR_IASI_SND_02_V11) == false

    dims_in_giard = MetopDatasets.get_flexible_dim_fields(MetopDatasets.GIADR_IASI_SND_02_V11)
    giard_fields_with_dim = sort(collect(keys(dims_in_giard)))
    giard_flexible_dim_names = [dims_in_giard[k] for k in giard_fields_with_dim]

    @test giard_fields_with_dim ==
          [:brescia_num_altitudes_so2, :forli_num_layers_co, :forli_num_layers_hno3,
        :forli_num_layers_o3, :num_ozone_pcs, :num_pressure_levels_humidity, :num_pressure_levels_ozone,
        :num_pressure_levels_temp, :num_surface_emissivity_wavelengths,
        :num_temperature_pcs, :num_water_vapour_pcs]

    @test giard_flexible_dim_names ==
          [:NL_SO2, :NL_CO, :NL_HNO3, :NL_O3, :NPCO, :NLQ, :NLO, :NLT, :NEW, :NPCT, :NPCW]

    ## testData
    if isdir("testData")
        test_file = "testData/IASI_SND_02_M01_20241215173256Z_20241215173552Z_N_C_20241215182326Z"

        giard = read_first_record(test_file, MetopDatasets.GIADR_IASI_SND_02_V11)
        @test giard isa MetopDatasets.GIADR_IASI_SND_02_V11

        # test sizes against std values
        flex_sizes = MetopDatasets.get_iasi_l2_flex_size(giard)

        @test flex_sizes[:NEW] == 12
        @test flex_sizes[:NLO] == 101
        @test flex_sizes[:NLQ] == 101
        @test flex_sizes[:NLT] == 101
        @test flex_sizes[:NL_CO] == 19
        @test flex_sizes[:NL_HNO3] == 41
        @test flex_sizes[:NL_O3] == 41
        @test flex_sizes[:NL_SO2] == 5
        @test flex_sizes[:NPCT] == 28
        @test flex_sizes[:NPCW] == 18
        @test flex_sizes[:NPCO] == 10
        @test flex_sizes[:NEVA_CO] == 10
        @test flex_sizes[:NEVE_CO] == 190
        @test flex_sizes[:NEVA_HNO3] == 21
        @test flex_sizes[:NEVE_HNO3] == 861
        @test flex_sizes[:NEVA_O3] == 21
        @test flex_sizes[:NEVE_O3] == 861
        @test flex_sizes[:NERRT] == 406
        @test flex_sizes[:NERRW] == 171
        @test flex_sizes[:NERRO] == 55

        flexible_record_layout, total_mdr = open(test_file) do file_pointer
            main_header = MetopDatasets.native_read(
                file_pointer, MetopDatasets.MainProductHeader)
            return only(MetopDatasets.read_record_layouts(file_pointer, main_header)),
            main_header.total_mdr
        end

        @test flexible_record_layout.record_range[end] == total_mdr
        @test length(flexible_record_layout.offsets) == total_mdr
        @test length(flexible_record_layout.record_sizes) == total_mdr
        @test flexible_record_layout.flexible_dims_file == flex_sizes

        ### test dataset
        ds = MetopDataset(test_file)

        # test dims and size
        @test !isnothing(ds.dim)
        @test CDM.dimnames(ds["co_h_eigenvalues"]) ==
              ["NEVA_CO", "xtrack_sounder_pixels", "atrack"]
        @test size(ds["co_h_eigenvalues"]) == (10, 120, 22)

        # test read 
        @test all(isapprox.(ds["fg_qi_surface_temperature"][1:5, 3],
            [1.7000000000000002, 1.5, 1.8, 1.6, 2.6]))

        # test that lazy load work for complex indexes with missing values
        weird_index = (4:2:10, 119:-2:3, 3:5)
        lazy_read = ds["hno3_cp_air"][weird_index...]
        eager_read = Array(ds["hno3_cp_air"])[weird_index...]
        no_data = ismissing.(lazy_read)

        @test lazy_read[.!no_data] == lazy_read[.!no_data]

        #test with NaNs instead of missing 
        var_no_missing = cfvariable(ds, "hno3_cp_air", maskingvalue = NaN)
        data_with_NaNs = var_no_missing[weird_index...]

        @test isnan.(data_with_NaNs) == no_data
        @test !any(ismissing, data_with_NaNs)

        # check variables from giard
        @test "pressure_levels_temp" in MetopDatasets.CDM.varnames(ds)
        @test MetopDatasets.CDM.dimnames(ds["pressure_levels_humidity"]) ==
              ["NLQ"]

        # manuel read levels from giadr
        temp_pressure_levels, hum_pressure_levels = let
            giard = MetopDatasets.read_first_record(ds, MetopDatasets.GIADR_IASI_SND_02_V11)

            scale_factor_temp = MetopDatasets.get_scale_factor(
                MetopDatasets.GIADR_IASI_SND_02_V11, :pressure_levels_temp)
            temp_level = giard.pressure_levels_temp / 10^scale_factor_temp
            scale_factor_humidity = MetopDatasets.get_scale_factor(
                MetopDatasets.GIADR_IASI_SND_02_V11, :pressure_levels_humidity)
            humidity_level = giard.pressure_levels_humidity / 10^scale_factor_humidity
            temp_level, humidity_level
        end

        @test isapprox(ds["pressure_levels_temp"][:], temp_pressure_levels)
        @test isapprox(ds["pressure_levels_humidity"][:], hum_pressure_levels)

        @test MetopDatasets.dimnames(ds["pressure_levels_temp"]) == ["NLT"]
        @test MetopDatasets.dimnames(ds["pressure_levels_humidity"]) == ["NLQ"]

        close(ds)

        # set masking value for entire data set.
        ds_no_missing = MetopDataset(test_file, maskingvalue = NaN)
        @test ds_no_missing["hno3_cp_air"][weird_index...][.!no_data] ==
              data_with_NaNs[.!no_data]
        close(ds_no_missing)
    end
end

@testset "IASI L02 V10 data records" begin
    @test MetopDatasets.fixed_size(MetopDatasets.IASI_SND_02_V10) == false

    # giard
    @test MetopDatasets.fixed_size(MetopDatasets.GIADR_IASI_SND_02_V10) == false

    ## testData
    if isdir("testData")
        test_file = "testData/IASI_SND_02_M02_20100202135952Z_20100202153856Z_N_O_20100202154539Z.nat"

        ds = MetopDataset(test_file)

        # test size
        @test ds.dim[MetopDatasets.RECORD_DIM_NAME] == parse(Int, ds.attrib["total_mdr"])

        @test Array(ds["pressure_levels_temp"]) isa Vector{Union{Missing, Float64}}
        @test MetopDatasets.CDM.dimnames(ds["pressure_levels_ozone"]) ==
              ["n_o3_profiles", "NLO"]

        @test all(lat -> -90 < lat < 90, ds["earth_location"][1, :, :])
        @test all(lon -> -180 < lon < 180, ds["earth_location"][2, :, :])

        # test error field
        error_field_dims = Int.(ds["data_sizes"][:, :, :])
        elem_size = 5
        error_field_size_computed = [sum(error_field_dims[1, :, i] * elem_size)
                                     for i in 1:ds.dim["atrack"]]
        error_field = ds["error_data"][49]

        @test error_field isa Vector{UInt8}
        @test length(error_field) == error_field_size_computed[49]
        @test length.(ds["error_data"][1:2]) == error_field_size_computed[1:2]

        close(ds)
    end
end

@testset "IASI L02 improved ordering" begin
    ## testData
    if isdir("testData")
        ds = MetopDataset("testData/IASI_SND_02_M01_20241215173256Z_20241215173552Z_N_C_20241215182326Z")

        @test size(ds["co_cp_air"]) ==
              (ds.dim["NL_CO"], ds.dim["xtrack_sounder_pixels"], ds.dim["atrack"])
        @test size(ds["co_cp_co_a"]) ==
              (ds.dim["NL_CO"], ds.dim["xtrack_sounder_pixels"], ds.dim["atrack"])
        @test size(ds["co_h_eigenvectors"]) ==
              (ds.dim["NEVE_CO"], ds.dim["xtrack_sounder_pixels"], ds.dim["atrack"])
        @test size(ds["temperature_error"]) ==
              (ds.dim["NERRT"], ds.dim["xtrack_sounder_pixels"], ds.dim["atrack"])

        @test MetopDatasets.dimnames(ds["co_cp_air"]) ==
              ["NL_CO", "xtrack_sounder_pixels", "atrack"]
        @test MetopDatasets.dimnames(ds["co_cp_co_a"]) ==
              ["NL_CO", "xtrack_sounder_pixels", "atrack"]
        @test MetopDatasets.dimnames(ds["co_h_eigenvectors"]) ==
              ["NEVE_CO", "xtrack_sounder_pixels", "atrack"]
        @test MetopDatasets.dimnames(ds["temperature_error"]) ==
              ["NERRT", "xtrack_sounder_pixels", "atrack"]

        expected_out_co = Union{Missing, Float64}[
            missing, 1.4418e24, 1.456e24, 1.4531e24, 1.4321e24, 1.4257e24,
            1.4271e24, missing, 1.4425e24, 1.4295e24, 1.4225e24,
            1.4351e24, 1.4498e24, 1.4304e24, 1.4387e24,
            1.4497e24, 1.4254e24, 1.4249e24, 1.4247e24, 1.425e24,
            1.4405e24, 1.44e24, 1.4399e24, 1.4404e24,
            1.4408e24, 1.456e24, 1.4265e24, 1.4326e24, 1.5042e24,
            1.4039e24, 1.4704e24, 1.3856e24, 1.4287e24,
            1.4185e24, 1.4446e24, 1.4619e24, 1.4363e24, 1.4401e24,
            1.4363e24, 1.4324e24, 1.4352e24, 1.4353e24,
            1.4352e24, 1.4352e24, 1.4241e24, 1.4244e24, 1.4242e24,
            1.424e24, 1.4289e24, 1.4288e24, 1.4285e24,
            1.4287e24, 1.4302e24, 1.4301e24, 1.4297e24, 1.4299e24,
            1.4312e24, 1.4311e24, 1.4307e24, 1.431e24, 1.4301e24,
            1.4303e24, 1.4301e24, 1.4299e24, 1.4417e24, 1.4418e24,
            1.4416e24, 1.4416e24, 1.4368e24, 1.4373e24, 1.4371e24,
            1.4367e24, 1.4437e24, 1.444e24, 1.4439e24, 1.4437e24, 1.4469e24,
            1.4469e24, 1.4469e24, 1.4469e24, 1.4443e24,
            1.4442e24, 1.4443e24, 1.4444e24, 1.4434e24, 1.444e24,
            1.4441e24, 1.4435e24, 1.445e24, 1.4456e24, 1.4457e24,
            1.4452e24, 1.4483e24, 1.4482e24, 1.4488e24, 1.4489e24,
            1.4526e24, 1.4523e24, 1.4527e24, 1.4531e24, 1.4487e24,
            1.4484e24, 1.4489e24, 1.4492e24, missing, missing, missing,
            missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, 1.4219e24, 1.4217e24, missing]

        actual_out_co = ds["co_cp_air"][6, :, 3]

        @test ismissing.(expected_out_co) == ismissing.(actual_out_co) #check locations of missing

        ## double check this test. Maybe the test is wrong???
        @test all(isapprox.(
            skipmissing(expected_out_co), skipmissing(actual_out_co), rtol = 0.01)) # check values

        expected_out_error = [missing, missing, missing, 0x3f1cabf0, missing, missing,
            missing, 0x3f2c95f2, 0x3f47461b, 0x3f3db0e1, 0x3f38dabb,
            missing, missing, missing, missing, 0x3f67aa78, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing,
            0x3f61a3f8, 0x3f6265c5, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing, missing,
            missing, missing, missing, missing, missing, missing, missing, missing]

        actual_out_error = ds["temperature_error"][12, :, 8]

        @test ismissing.(expected_out_error) == ismissing.(actual_out_error) #check locations of missing
        @test all(isapprox.(skipmissing(expected_out_error), skipmissing(actual_out_error))) # check values

        # test that the reader support complex indexes into the flexible dimension.
        weird_index = 120:-2:8
        temp_e_array_index = Array(ds["temperature_error"])[:, weird_index, :]
        temp_e_disk_array_index = ds["temperature_error"][:, weird_index, :]

        @test all(skipmissing(temp_e_array_index) .== skipmissing(temp_e_disk_array_index))
        @test ismissing.(temp_e_array_index) == ismissing.(temp_e_disk_array_index)

        close(ds)
    end
end
