# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Test
import CommonDataModel as CDM

const TEST_DATA_ARTIFACT = MetopDatasets.get_test_data_artifact()
const GOME2_BUNDLED_FIXTURE_DIR = joinpath(@__DIR__, "fixtures", "gome2")
const GOME2_ARTIFACT_SUBDIRS = (
    "",
    "GOMEL1",
    "GOMEL1R03",
    joinpath("metop", "GOMEL1"),
    joinpath("metop", "GOMEL1R03"))
const GOME2_V13_FILE_NAME = "GOME_xxx_1B_M02_20200101120000Z_20200101133500Z_N_O_20200101140000Z"
const GOME2_V12_FILE_NAME = "GOME_xxx_1B_M01_20200730235354Z_20200731013554Z_R_O_20201017174130Z_0300"

function _resolve_gome2_fixture(file_name::AbstractString)
    for subdir in GOME2_ARTIFACT_SUBDIRS
        artifact_file = isempty(subdir) ? joinpath(TEST_DATA_ARTIFACT, file_name) :
                        joinpath(TEST_DATA_ARTIFACT, subdir, file_name)
        if isfile(artifact_file)
            return artifact_file
        end
    end

    bundled_file = joinpath(GOME2_BUNDLED_FIXTURE_DIR, file_name)
    if isfile(bundled_file)
        return bundled_file
    end
    return ""
end

const GOME2_V13_FILE = _resolve_gome2_fixture(GOME2_V13_FILE_NAME)
const GOME2_V12_FILE = _resolve_gome2_fixture(GOME2_V12_FILE_NAME)

function _decode_centre_component(centre::AbstractMatrix,
        scan_index::Int, component_index::Int)
    half_scans = 16
    local_scan = scan_index <= half_scans ? scan_index : (scan_index - half_scans)
    col = scan_index <= half_scans ? 1 : 2
    row = 2 * local_scan - (component_index == 1 ? 1 : 0)
    val = centre[row, col]
    return ismissing(val) ? NaN : Float64(val)
end

# EFG triplets use BSQ (sequential) layout: [E0..E31, F0..F31, G0..G31].
# Julia's column-major reshape of (32, 3) naturally maps column 1=E, 2=F, 3=G,
# so sat_zenith[:, 2, :] directly gives the F-component values.
function _assert_sat_zenith_triplet_layout(ds::MetopDataset)
    sat_zenith_raw = ds["sat_zenith"][:, :, :]
    f_component = Float64.(coalesce.(sat_zenith_raw[:, 2, :], NaN))

    finite_f = f_component[isfinite.(f_component)]
    @test !isempty(finite_f)
    @test all(-1 .<= finite_f .<= 90)

    # E and G components should bracket F (E >= F >= G for zenith angles)
    e_component = Float64.(coalesce.(sat_zenith_raw[:, 1, :], NaN))
    g_component = Float64.(coalesce.(sat_zenith_raw[:, 3, :], NaN))
    common = isfinite.(e_component) .& isfinite.(f_component) .& isfinite.(g_component)
    @test any(abs.(e_component[common] .- f_component[common]) .> 1e-6)
    return nothing
end

@testset "GOME-2 L1B record types" begin
    @test MetopDatasets.GOME_XXX_1B_V13 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_V12 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B <: MetopDatasets.DataRecord
    @test MetopDatasets.fixed_size(MetopDatasets.GOME_XXX_1B_V13) == false
    @test MetopDatasets.fixed_size(MetopDatasets.GOME_XXX_1B_V12) == false
    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_V13) == 6
    @test MetopDatasets.gome2_band_record_sizes(MetopDatasets.GOME_XXX_1B_V13) ==
          (12, 12, 12, 12, 12, 12, 16, 16, 16, 16)
    @test MetopDatasets.gome2_band_record_sizes(MetopDatasets.GOME_XXX_1B_V12) ==
          (12, 12, 12, 12, 12, 12, 16, 16, 16, 16)
    @test MetopDatasets.has_uncorrected_pmd(MetopDatasets.GOME_XXX_1B_V13)
    @test MetopDatasets.has_uncorrected_pmd(MetopDatasets.GOME_XXX_1B_V12)
end

@testset "GOME-2 spectral fill tuple decoding" begin
    to_u8(x::Int8) = reinterpret(UInt8, [x])[1]
    bebytes(x::Int16) = reinterpret(UInt8, [hton(x)])
    bebytes(x::Int32) = reinterpret(UInt8, [hton(x)])

    main_fill = zeros(UInt8, 12)
    main_fill[1] = to_u8(typemin(Int8))
    main_fill[2:5] .= bebytes(typemin(Int32))
    @test isnan(MetopDatasets._extract_band_component(
        Float64, main_fill, 1, :radiance, false, true))

    main_error_fill = zeros(UInt8, 12)
    main_error_fill[6] = to_u8(typemin(Int8))
    main_error_fill[7:8] .= bebytes(typemin(Int16))
    @test isnan(MetopDatasets._extract_band_component(
        Float64, main_error_fill, 1, :radiance_error, false, true))

    stokes_fill = zeros(UInt8, 12)
    stokes_fill[9:12] .= bebytes(typemin(Int32))
    @test isnan(MetopDatasets._extract_band_component(
        Float64, stokes_fill, 1, :stokes_fraction, false, true))

    pmd_fill = zeros(UInt8, 16)
    pmd_fill[9] = to_u8(typemin(Int8))
    pmd_fill[10:13] .= bebytes(typemin(Int32))
    @test isnan(MetopDatasets._extract_band_component(
        Float64, pmd_fill, 1, :uncorrected_radiance, true, true))

    pmd_error_fill = zeros(UInt8, 16)
    pmd_error_fill[14] = to_u8(typemin(Int8))
    pmd_error_fill[15:16] .= bebytes(typemin(Int16))
    @test isnan(MetopDatasets._extract_band_component(
        Float64, pmd_error_fill, 1, :uncorrected_radiance_error, true, true))

    main_valid = zeros(UInt8, 12)
    main_valid[1] = to_u8(Int8(2))
    main_valid[2:5] .= bebytes(Int32(123456))
    @test MetopDatasets._extract_band_component(
        Float64, main_valid, 1, :radiance, false, true) ≈ 1234.56
end

@testset "GOME-2 lazy spectral cache" begin
    if !isfile(GOME2_V13_FILE)
        @info "Skipping GOME-2 cache test: test file not found at $GOME2_V13_FILE"
        return
    end

    spectral_key = :gome2_spectral_info
    output_selection_key = :gome2_output_selection_info

    ds = MetopDataset(GOME2_V13_FILE)

    @test !haskey(ds.cache, spectral_key)
    _ = CDM.dimnames(ds)
    @test !haskey(ds.cache, spectral_key)
    _ = CDM.dim(ds, "scan_position")
    @test !haskey(ds.cache, spectral_key)

    _ = CDM.dim(ds, "wavelength_1a")
    @test haskey(ds.cache, spectral_key)
    close(ds)
    @test isempty(ds.cache)

    ds = MetopDataset(GOME2_V13_FILE)
    @test !haskey(ds.cache, output_selection_key)
    rad_var = CDM.variable(ds, "radiance_1a")
    _ = CDM.attrib(rad_var, "output_selection_mode")
    @test haskey(ds.cache, output_selection_key)
    close(ds)
    @test isempty(ds.cache)
end

@testset "GOME-2 raw record API disabled" begin
    if !isfile(GOME2_V13_FILE)
        @info "Skipping GOME-2 raw record API test: test file not found at $GOME2_V13_FILE"
        return
    end

    err = try
        MetopDatasets.read_first_record(GOME2_V13_FILE, MetopDatasets.GOME_XXX_1B_V13)
        nothing
    catch ex
        ex
    end
    @test err isa ErrorException
    @test occursin("Raw-record API is disabled", sprint(showerror, err))
end

@testset "GOME-2 auto_convert gating" begin
    if !isfile(GOME2_V13_FILE)
        @info "Skipping GOME-2 auto_convert test: test file not found at $GOME2_V13_FILE"
        return
    end

    ds = MetopDataset(GOME2_V13_FILE; auto_convert = false)
    all_names = Set(CDM.varnames(ds))
    @test !("wavelength_1a" in all_names)
    @test !("radiance_1a" in all_names)
    @test "latitude" in all_names
    @test "longitude" in all_names
    @test_throws KeyError CDM.variable(ds, "radiance_1a")
    @test !("wavelength_1a" in CDM.dimnames(ds))
    @test !("readout_1a" in CDM.dimnames(ds))
    @test !haskey(ds.cache, :gome2_spectral_info)
    _ = CDM.dims(ds)
    @test !haskey(ds.cache, :gome2_spectral_info)
    close(ds)
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

    @testset "SAT_ZENITH triplet decoding" begin
        _assert_sat_zenith_triplet_layout(ds)
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
        @test minimum(wl_4_vals) > 200
        @test maximum(wl_4_vals) < 1000
        @test issorted(wl_4_vals)
    end

    @testset "Radiance variables" begin
        rad_1a = ds["radiance_1a"]
        @test ndims(rad_1a) == 3  # (max_rec_length, max_num_recs, n_records)
        @test CDM.dimnames(rad_1a) == ["wavelength_1a", "readout_1a", "atrack"]

        # Read a small subset
        r = rad_1a[1:5, 1, 1]
        @test length(r) == 5
        @test eltype(r) in (Float64, Union{Missing, Float64})

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
        @test isnan(CDM.attrib(wl_var, "missing_value"))
        @test isnan(CDM.attrib(wl_var, "_FillValue"))
        @test CDM.attrib(wl_var, "output_selection_mode") in ("0", "1", "mixed", "unknown")
        @test CDM.attrib(wl_var, "output_selection_values") isa String

        output_selection = unique(skipmissing(ds["output_selection"][:]))
        @test length(output_selection) >= 1

        rad_var = CDM.variable(ds, "radiance_1a")
        @test isnan(CDM.attrib(rad_var, "missing_value"))
        @test isnan(CDM.attrib(rad_var, "_FillValue"))

        if length(output_selection) == 1
            mode_val = Int(only(output_selection))
            if mode_val == 0
                @test CDM.attrib(rad_var, "output_selection_mode") == "0"
                @test CDM.attrib(rad_var, "units") == "photon s-1 cm-2 nm-1 sr-1"
                @test occursin("Calibrated radiance", CDM.attrib(rad_var, "description"))
            elseif mode_val == 1
                @test CDM.attrib(rad_var, "output_selection_mode") == "1"
                @test CDM.attrib(rad_var, "units") == "1"
                @test occursin("Sun-normalized radiance", CDM.attrib(rad_var, "description"))
            end
        end

        rec_length_var = CDM.variable(ds, "rec_length_1a")
        @test CDM.attrib(rec_length_var, "output_selection_mode") in (
            "0", "1", "mixed", "unknown")
    end

    @testset "Geolocation component-order metadata" begin
        centre_var = CDM.variable(ds, "centre")
        @test CDM.attrib(centre_var, "geo_component_order") == "latitude, longitude"
        @test occursin("geo_component order: latitude, longitude",
            CDM.attrib(centre_var, "description"))

        for field_name in ("corner", "scan_centre", "scan_corner", "sub_satellite_point")
            v = CDM.variable(ds, field_name)
            @test CDM.attrib(v, "geo_component_order") == "latitude, longitude"
        end

        centre = ds["centre"][:, :, 1]
        lat = ds["latitude"][:, 1]
        lon = ds["longitude"][:, 1]
        lat_expected = [_decode_centre_component(centre, s, 1) for s in 1:32]
        lon_expected = [_decode_centre_component(centre, s, 2) for s in 1:32]
        @test all(isapprox.(lat, lat_expected; atol = 1e-10, rtol = 0))
        @test all(isapprox.(lon, lon_expected; atol = 1e-10, rtol = 0))
    end

    close(ds)
end

@testset "GOME-2 L1B V12 dataset" begin
    if !isfile(GOME2_V12_FILE)
        @info "Skipping GOME-2 V12 test: test file not found at $GOME2_V12_FILE"
        return
    end

    ds = MetopDataset(GOME2_V12_FILE)
    @test ds.main_product_header.format_major_version == 12
    @test typeof(ds).parameters[1] == MetopDatasets.GOME_XXX_1B_V12

    centre_var = CDM.variable(ds, "centre")
    @test CDM.attrib(centre_var, "geo_component_order") == "latitude, longitude"

    centre = ds["centre"][:, :, 1]
    lat = ds["latitude"][:, 1]
    lon = ds["longitude"][:, 1]
    lat_expected = [_decode_centre_component(centre, s, 1) for s in 1:32]
    lon_expected = [_decode_centre_component(centre, s, 2) for s in 1:32]
    @test all(isapprox.(lat, lat_expected; atol = 1e-10, rtol = 0))
    @test all(isapprox.(lon, lon_expected; atol = 1e-10, rtol = 0))

    _assert_sat_zenith_triplet_layout(ds)

    close(ds)
end
