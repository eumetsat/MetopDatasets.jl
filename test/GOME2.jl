# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Test
import CommonDataModel as CDM

# GOME-2 L1B test data (V13/NRT format)
const GOME2_TEST_DIR = "/Users/jovan/oxidian/defair-core/test-data/metop/GOMEL1"
const GOME2_V13_FILE = joinpath(GOME2_TEST_DIR,
    "GOME_xxx_1B_M01_20250630125059Z_20250630142959Z_N_O_20250630134221Z.nat")

@testset "GOME-2 L1B record types" begin
    @test MetopDatasets.GOME_XXX_1B_V13 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_V12 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B <: MetopDatasets.DataRecord
    @test MetopDatasets.fixed_size(MetopDatasets.GOME_XXX_1B_V13) == false
    @test MetopDatasets.fixed_size(MetopDatasets.GOME_XXX_1B_V12) == false
    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_V13) == 6
end

@testset "GOME-2 L1B V13 dataset" begin
    if !isfile(GOME2_V13_FILE)
        @info "Skipping GOME-2 V13 test: test file not found at $GOME2_V13_FILE"
        return
    end

    ds = MetopDataset(GOME2_V13_FILE)

    @testset "Basic dataset properties" begin
        @test ds.main_product_header.format_major_version == 13
        @test ds.data_record_count > 0
        @test typeof(ds).parameters[1] == MetopDatasets.GOME_XXX_1B_V13
    end

    @testset "Dimension validation" begin
        @test MetopDatasets._valid_dimensions(ds)
    end

    @testset "Fixed-header variables" begin
        # Test that fixed-header fields are readable
        centre = ds["centre"]
        @test size(centre, 1) == 32  # scan positions
        @test size(centre, 2) == 2   # geo_component (lat/lon)

        sigma = ds["sigma_scene"]
        @test size(sigma, 1) == 32

        scanner = ds["scanner_angle"]
        @test size(scanner, 1) == 65

        solar_z = ds["solar_zenith"]
        @test size(solar_z, 1) == 32
        @test size(solar_z, 2) == 3  # EFG

        corner = ds["corner"]
        @test size(corner, 1) == 32
        @test size(corner, 2) == 4
        @test size(corner, 3) == 2
    end

    @testset "Latitude/Longitude" begin
        lat = ds["latitude"]
        lon = ds["longitude"]

        @test size(lat, 1) == 32
        @test size(lon, 1) == 32
        @test size(lat, 2) == ds.data_record_count
        @test size(lon, 2) == ds.data_record_count

        # Check plausible ranges
        lat_vals = lat[:, 1]
        lon_vals = lon[:, 1]
        @test all(-90 .<= lat_vals .<= 90)
        @test all(-180 .<= lon_vals .<= 360)

        # Check dimension names
        @test CDM.dimnames(lat) == ["scan_position", "atrack"]
        @test CDM.dimnames(lon) == ["scan_position", "atrack"]
    end

    @testset "Spectral layout variables" begin
        rl_1a = ds["rec_length_1a"]
        @test size(rl_1a) == (ds.data_record_count,)
        rl_vals = rl_1a[:]
        @test all(rl_vals .> 0)  # should have positive spectral element count

        nr_1a = ds["num_recs_1a"]
        @test size(nr_1a) == (ds.data_record_count,)
        nr_vals = nr_1a[:]
        @test all(nr_vals .> 0)
    end

    @testset "Wavelength variables" begin
        wl_1a = ds["wavelength_1a"]
        @test ndims(wl_1a) == 2  # (max_rec_length, n_records)
        @test CDM.dimnames(wl_1a) == ["wavelength_1a", "atrack"]

        # Check UV range for band 1a (~240-315 nm)
        wl_vals = wl_1a[:, 1]
        valid_wl = filter(!isnan, wl_vals)
        @test length(valid_wl) > 0
        @test minimum(valid_wl) > 190  # should be UV
        @test maximum(valid_wl) < 320

        # Wavelengths should be monotonically increasing
        @test issorted(valid_wl)

        # Check visible range for band 4 (~590-790 nm)
        wl_4 = ds["wavelength_4"]
        wl_4_vals = filter(!isnan, wl_4[:, 1])
        @test minimum(wl_4_vals) > 550
        @test maximum(wl_4_vals) < 800
        @test issorted(wl_4_vals)
    end

    @testset "Radiance variables" begin
        rad_1a = ds["radiance_1a"]
        @test ndims(rad_1a) == 3  # (max_rec_length, max_num_recs, n_records)
        @test CDM.dimnames(rad_1a) == ["wavelength_1a", "readout_1a", "atrack"]

        # Read a small subset
        r = rad_1a[1:5, 1, 1]
        @test length(r) == 5
        @test eltype(r) == Float64

        # Radiance error
        err = ds["radiance_error_1a"]
        @test ndims(err) == 3

        # Stokes fraction (main bands only)
        stokes = ds["stokes_fraction_1a"]
        @test ndims(stokes) == 3
    end

    @testset "PMD band variables" begin
        wl_pp = ds["wavelength_pp"]
        @test ndims(wl_pp) == 2

        rad_pp = ds["radiance_pp"]
        @test ndims(rad_pp) == 3

        # PMD bands have uncorrected radiance
        uncorr = ds["uncorrected_radiance_pp"]
        @test ndims(uncorr) == 3

        uncorr_err = ds["uncorrected_radiance_error_pp"]
        @test ndims(uncorr_err) == 3
    end

    @testset "Variable descriptions and attributes" begin
        lat_var = CDM.variable(ds, "latitude")
        @test CDM.attrib(lat_var, "description") ==
              "Latitude extracted from CENTRE field (-90 to 90 deg)"

        wl_var = CDM.variable(ds, "wavelength_1a")
        @test CDM.attrib(wl_var, "description") == "Wavelength for band 1a (nm)"
    end

    close(ds)
end
