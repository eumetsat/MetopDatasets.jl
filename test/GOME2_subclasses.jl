# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Test
import CommonDataModel as CDM

# Heavy end-to-end tests run when GOME2_L1B_FULL_TEST_FILE points at a
# Metop L1B granule containing Sun and Calibration MDRs, and when
# GOME2_L1B_MOON_TEST_FILE points at a granule containing Moon MDRs (caught
# during one of the ~monthly lunar calibration campaigns, July–December).
# The cropped artefact used by test/GOME2.jl carries Earthshine only.
const GOME2_L1B_FULL_FILE = get(ENV, "GOME2_L1B_FULL_TEST_FILE", "")
const GOME2_L1B_MOON_FILE = get(ENV, "GOME2_L1B_MOON_TEST_FILE", "")
# Optional V12 (FDR R3) granules, same subclass content as the V13 pair.
const GOME2_L1B_V12_FULL_FILE = get(ENV, "GOME2_L1B_V12_FULL_TEST_FILE", "")
const GOME2_L1B_V12_MOON_FILE = get(ENV, "GOME2_L1B_V12_MOON_TEST_FILE", "")

@testset "GOME-2 L1B subclass record types" begin
    @test MetopDatasets.GOME_XXX_1B_SUN_V13 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_SUN_V12 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_MOON_V13 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_MOON_V12 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_CALIBRATION_V13 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_CALIBRATION_V12 <: MetopDatasets.GOME_XXX_1B

    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_V13) == 6
    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_CALIBRATION_V13) ==
          7
    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_SUN_V13) == 8
    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_MOON_V13) == 9

    @test MetopDatasets.has_geo_earth_actual_prefix(MetopDatasets.GOME_XXX_1B_V13)
    @test !MetopDatasets.has_geo_earth_actual_prefix(MetopDatasets.GOME_XXX_1B_SUN_V13)
    @test !MetopDatasets.has_geo_earth_actual_prefix(MetopDatasets.GOME_XXX_1B_MOON_V13)
    @test !MetopDatasets.has_geo_earth_actual_prefix(MetopDatasets.GOME_XXX_1B_CALIBRATION_V13)

    for T in (MetopDatasets.GOME_XXX_1B_SUN_V13,
        MetopDatasets.GOME_XXX_1B_MOON_V13,
        MetopDatasets.GOME_XXX_1B_CALIBRATION_V13)
        @test MetopDatasets.fixed_size(T) == false
        @test MetopDatasets.gome2_band_record_sizes(T) ==
              (12, 12, 12, 12, 12, 12, 16, 16, 16, 16)
    end
end

@testset "GOME-2 subclass type selection" begin
    @test MetopDatasets._get_subclass_type(MetopDatasets.GOME_XXX_1B_V13, :default) ===
          MetopDatasets.GOME_XXX_1B_V13
    @test MetopDatasets._get_subclass_type(MetopDatasets.GOME_XXX_1B_V13, :earthshine) ===
          MetopDatasets.GOME_XXX_1B_V13
    @test MetopDatasets._get_subclass_type(MetopDatasets.GOME_XXX_1B_V13, :sun) ===
          MetopDatasets.GOME_XXX_1B_SUN_V13
    @test MetopDatasets._get_subclass_type(MetopDatasets.GOME_XXX_1B_V12, :moon) ===
          MetopDatasets.GOME_XXX_1B_MOON_V12
    @test MetopDatasets._get_subclass_type(MetopDatasets.GOME_XXX_1B_V13, :calibration) ===
          MetopDatasets.GOME_XXX_1B_CALIBRATION_V13
    @test_throws ErrorException MetopDatasets._get_subclass_type(
        MetopDatasets.GOME_XXX_1B_V13, :unknown_subclass)

    # generic fallback for record types without subclasses
    @test MetopDatasets._get_subclass_type(MetopDatasets.ASCA_SZR_1B_V13, :default) ===
          MetopDatasets.ASCA_SZR_1B_V13
    @test_throws ErrorException MetopDatasets._get_subclass_type(
        MetopDatasets.ASCA_SZR_1B_V13, :earthshine)
end

@testset "GOME-2 L1B subclass groups on real file" begin
    if !isfile(GOME2_L1B_FULL_FILE)
        @info "Skipping GOME-2 subclass real-file tests: set " *
              "GOME2_L1B_FULL_TEST_FILE to a Metop L1B granule with Sun & " *
              "Calibration MDRs"
        return
    end

    expected_counts = Dict(
        "earthshine" => 527, "calibration" => 433, "sun" => 33)

    ds = MetopDataset(GOME2_L1B_FULL_FILE)

    @testset "Root dataset and group names" begin
        @test sort(CDM.groupnames(ds)) == sort(collect(keys(expected_counts)))
        @test isempty(CDM.varnames(ds))
        @test isempty(CDM.dimnames(ds))
        # global attributes are available on the root
        @test CDM.attrib(ds, "format_major_version") == "13"
        # variables are only accessible through the groups
        @test_throws ErrorException ds["radiance_1a"]
        # absent subclass
        @test !("moon" in CDM.groupnames(ds))
        @test_throws ErrorException CDM.group(ds, "moon")
    end

    @testset "Group navigation" begin
        earthshine = CDM.group(ds, "earthshine")
        @test CDM.name(earthshine) == "earthshine"
        @test CDM.parentdataset(earthshine) === ds
        @test CDM.name(ds) == "/"
        @test isnothing(CDM.parentdataset(ds))
        # groups are cached
        @test CDM.group(ds, "earthshine") === earthshine
    end

    @testset "Record counts and spectral shapes" begin
        for (group_name, n) in expected_counts
            g = CDM.group(ds, group_name)
            @test g.data_record_count == n

            rad = g["radiance_1a"]
            @test ndims(rad) == 3
            @test size(rad, 3) == n

            wl = g["wavelength_1a"]
            @test ndims(wl) == 2
            @test size(wl, 2) == n

            # Band 1a covers the UV around 240–315 nm
            wl_vals = collect(skipmissing(wl[:, 1]))
            @test length(wl_vals) > 0
            @test minimum(wl_vals) > 190
            @test maximum(wl_vals) < 320
        end
    end

    @testset "FPA temperature uses main_bands dimension" begin
        g = CDM.group(ds, "sun")
        fpa = g["fpa_temp"]
        @test size(fpa, 1) == 6
        @test CDM.dimnames(fpa) == ["main_bands", "atrack"]
        @test CDM.dim(g, "main_bands") == 6
        # earthshine has no fpa_temp and no main_bands dimension
        earthshine = CDM.group(ds, "earthshine")
        @test !("main_bands" in CDM.dimnames(earthshine))
    end

    @testset "Earthshine-only variables gated on non-Earthshine subclass" begin
        g = CDM.group(ds, "sun")
        @test_throws ErrorException g["latitude"]
        @test_throws ErrorException g["longitude"]
    end

    @testset "Sun measurement-mode metadata" begin
        g = CDM.group(ds, "sun")
        rad_var = CDM.variable(g, "radiance_1a")
        @test CDM.attrib(rad_var, "units") == "photon s-1 cm-2 nm-1"
        @test CDM.attrib(rad_var, "output_selection_mode") == "solar_irradiance"
    end

    @testset "Sun radiance has finite values across bands" begin
        # Regression guard for `_decode_vinteger_or_nan`: a bug that silently
        # turns real readings into fill (or fill into spurious finite
        # garbage) would slip past the shape/metadata checks above.
        g = CDM.group(ds, "sun")
        for bname in ("1a", "3", "pp")
            v = g["radiance_$bname"][:, :, :]
            finite = [x for x in vec(v) if !ismissing(x) && isfinite(x)]
            @test !isempty(finite)
            @test length(finite) > 100
        end
    end

    @testset "Calibration measurement-mode metadata" begin
        g = CDM.group(ds, "calibration")
        rad_var = CDM.variable(g, "radiance_1a")
        @test CDM.attrib(rad_var, "units") == "photon s-1 cm-2 nm-1 sr-1"
        # Mode is derived from per-record OBSERVATION_MODE; one of the
        # calibration_* labels.
        mode = CDM.attrib(rad_var, "output_selection_mode")
        @test startswith(mode, "calibration_")
        # The granule used for the heavy tests contains Dark, WLS and SLS
        # records together, so the resolved mode is `calibration_mixed`.
        @test mode == "calibration_mixed"
        @test occursin("dark", CDM.attrib(rad_var, "comment"))
    end

    close(ds)
end

@testset "GOME-2 L1B Moon subclass on real file" begin
    if !isfile(GOME2_L1B_MOON_FILE)
        @info "Skipping GOME-2 Moon real-file tests: set " *
              "GOME2_L1B_MOON_TEST_FILE to a Metop L1B granule from a " *
              "lunar calibration campaign (~5 days after full moon, " *
              "July–December)"
        return
    end

    root = MetopDataset(GOME2_L1B_MOON_FILE)
    @test "moon" in CDM.groupnames(root)
    ds = CDM.group(root, "moon")

    @testset "Record count and spectral shape" begin
        @test ds.data_record_count > 0

        rad = ds["radiance_1a"]
        @test ndims(rad) == 3
        @test size(rad, 3) == ds.data_record_count

        wl = ds["wavelength_1a"]
        wl_vals = collect(skipmissing(wl[:, 1]))
        @test length(wl_vals) > 0
        @test minimum(wl_vals) > 190
        @test maximum(wl_vals) < 320
    end

    @testset "Moon-specific GEO_MOON fields" begin
        # The 5-element HJKLM lunar pointing vectors use the new `lunar_point` dim.
        @test CDM.dimnames(ds["lunar_azimuth"]) == ["lunar_point", "atrack"]
        @test CDM.dimnames(ds["lunar_elevation"]) == ["lunar_point", "atrack"]

        # Physically sensible scalar values for the first Moon record.
        lp = ds["lunar_phase"][1]
        @test 0 <= lp <= 180  # geometric phase angle, deg
        lf = ds["lunar_fraction"][1]
        @test 0 <= lf <= 1    # illuminated fraction
        d_sat_moon = ds["distance_sat_moon"][1]
        @test 300e6 < d_sat_moon < 450e6  # m; Earth–Moon distance ~360–405 Mm
        d_sun_moon = ds["distance_sun_moon"][1]
        @test 1.40e11 < d_sun_moon < 1.55e11  # m; Sun–Moon distance ~1 AU
    end

    @testset "Lunar-radiance metadata" begin
        rad_var = CDM.variable(ds, "radiance_1a")
        @test CDM.attrib(rad_var, "units") == "photon s-1 cm-2 nm-1 sr-1"
        @test CDM.attrib(rad_var, "output_selection_mode") == "lunar_radiance"
    end

    @testset "Lunar PMD radiances are finite, main channels are fill" begin
        # During Moon calibration, the main spectrometer channels (1a-4)
        # record no signal — the granule contains EUMETSAT fill markers
        # (typemin(Int8)/typemin(Int32)) for those bands. PMD broadband
        # channels capture the lunar reflectance and decode to real
        # photon-flux radiances. This split is the parser's main correctness
        # signal for Moon data: a regression that confuses fill vs. real
        # values would flip both behaviours.
        for bname in ("1a", "1b", "3", "4")
            v = ds["radiance_$bname"][:, :, :]
            finite = [x for x in vec(v) if !ismissing(x) && isfinite(x)]
            @test isempty(finite)  # all instrument-fill, by design
        end
        for bname in ("pp", "ps", "swps")
            v = ds["radiance_$bname"][:, :, :]
            finite = [x for x in vec(v) if !ismissing(x) && isfinite(x)]
            @test length(finite) > 1000
        end
    end

    close(root)
end

@testset "GOME-2 L1B V12 subclass groups on real file" begin
    if !isfile(GOME2_L1B_V12_FULL_FILE)
        @info "Skipping GOME-2 V12 subclass real-file tests: set " *
              "GOME2_L1B_V12_FULL_TEST_FILE to a FDR R3 granule with Sun & " *
              "Calibration MDRs"
        return
    end

    expected_counts = Dict(
        "earthshine" => 497, "calibration" => 444, "sun" => 33)

    ds = MetopDataset(GOME2_L1B_V12_FULL_FILE)
    @test CDM.attrib(ds, "format_major_version") == "12"
    @test sort(CDM.groupnames(ds)) == sort(collect(keys(expected_counts)))

    for (group_name, n) in expected_counts
        g = CDM.group(ds, group_name)
        @test typeof(g).parameters[1] <: MetopDatasets.GOME_XXX_1B
        @test g.data_record_count == n

        # Band 1a covers the UV; sanity-check the wavelength grid.
        wl_vals = collect(skipmissing(g["wavelength_1a"][:, 1]))
        @test length(wl_vals) > 0
        @test minimum(wl_vals) > 190
        @test maximum(wl_vals) < 320

        # Every subclass carries decodable radiances.
        v = g["radiance_3"][:, :, :]
        finite = count(x -> !ismissing(x) && isfinite(x), vec(v))
        @test finite > 1000
    end

    sun_rad = CDM.variable(CDM.group(ds, "sun"), "radiance_1a")
    @test CDM.attrib(sun_rad, "units") == "photon s-1 cm-2 nm-1"
    @test CDM.attrib(sun_rad, "output_selection_mode") == "solar_irradiance"

    fpa = CDM.group(ds, "sun")["fpa_temp"]
    @test CDM.dimnames(fpa) == ["main_bands", "atrack"]
    # Focal-plane assemblies are held around -38 °C (~235 K).
    @test all(200 .< skipmissing(fpa[:, 1]) .< 250)

    close(ds)
end

@testset "GOME-2 L1B V12 Moon subclass on real file" begin
    if !isfile(GOME2_L1B_V12_MOON_FILE)
        @info "Skipping GOME-2 V12 Moon real-file tests: set " *
              "GOME2_L1B_V12_MOON_TEST_FILE to a FDR R3 granule from a " *
              "lunar calibration campaign"
        return
    end

    root = MetopDataset(GOME2_L1B_V12_MOON_FILE)
    @test "moon" in CDM.groupnames(root)
    ds = CDM.group(root, "moon")
    @test ds.data_record_count > 0

    @test CDM.dimnames(ds["lunar_azimuth"]) == ["lunar_point", "atrack"]
    lp = ds["lunar_phase"][1]
    @test 0 <= lp <= 180
    lf = ds["lunar_fraction"][1]
    @test 0 <= lf <= 1
    d_sat_moon = ds["distance_sat_moon"][1]
    @test 300e6 < d_sat_moon < 450e6

    rad_var = CDM.variable(ds, "radiance_pp")
    @test CDM.attrib(rad_var, "output_selection_mode") == "lunar_radiance"
    v = ds["radiance_pp"][:, :, :]
    finite = count(x -> !ismissing(x) && isfinite(x), vec(v))
    @test finite > 1000

    close(root)
end
