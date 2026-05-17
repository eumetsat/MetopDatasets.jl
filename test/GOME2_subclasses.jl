# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Test
import CommonDataModel as CDM

# Heavy end-to-end tests run when GOME2_L1B_FULL_TEST_FILE points at a
# Metop L1B granule containing Sun and Calibration MDRs (the cropped artefact
# used by test/GOME2.jl carries Earthshine only).
const GOME2_L1B_FULL_FILE = get(ENV, "GOME2_L1B_FULL_TEST_FILE", "")

@testset "GOME-2 L1B subclass record types" begin
    @test MetopDatasets.GOME_XXX_1B_SUN_V13         <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_SUN_V12         <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_MOON_V13        <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_MOON_V12        <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_CALIBRATION_V13 <: MetopDatasets.GOME_XXX_1B
    @test MetopDatasets.GOME_XXX_1B_CALIBRATION_V12 <: MetopDatasets.GOME_XXX_1B

    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_V13) == 6
    @test MetopDatasets.get_instrument_subclass(MetopDatasets.GOME_XXX_1B_CALIBRATION_V13) == 7
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

@testset "GOME-2 mdr_subclass type selection" begin
    @test MetopDatasets._gome2_subclass_type(MetopDatasets.GOME_XXX_1B_V13, :earthshine) ===
          MetopDatasets.GOME_XXX_1B_V13
    @test MetopDatasets._gome2_subclass_type(MetopDatasets.GOME_XXX_1B_V13, :sun) ===
          MetopDatasets.GOME_XXX_1B_SUN_V13
    @test MetopDatasets._gome2_subclass_type(MetopDatasets.GOME_XXX_1B_V12, :moon) ===
          MetopDatasets.GOME_XXX_1B_MOON_V12
    @test MetopDatasets._gome2_subclass_type(MetopDatasets.GOME_XXX_1B_V13, :calibration) ===
          MetopDatasets.GOME_XXX_1B_CALIBRATION_V13
    @test_throws ErrorException MetopDatasets._gome2_subclass_type(
        MetopDatasets.GOME_XXX_1B_V13, :unknown_subclass)
end

@testset "GOME-2 L1B subclass selection on real file" begin
    if !isfile(GOME2_L1B_FULL_FILE)
        @info "Skipping GOME-2 subclass real-file tests: set " *
              "GOME2_L1B_FULL_TEST_FILE to a Metop L1B granule with Sun & " *
              "Calibration MDRs"
        return
    end

    expected_counts = Dict(:earthshine => 496, :calibration => 433, :sun => 33)

    @testset "Record counts and spectral shapes" begin
        for (sc, n) in expected_counts
            ds = MetopDataset(GOME2_L1B_FULL_FILE; mdr_subclass = sc)
            @test ds.data_record_count == n

            rad = ds["radiance_1a"]
            @test ndims(rad) == 3
            @test size(rad, 3) == n

            wl = ds["wavelength_1a"]
            @test ndims(wl) == 2
            @test size(wl, 2) == n

            # Band 1a covers the UV around 240–315 nm
            wl_vals = collect(skipmissing(wl[:, 1]))
            @test length(wl_vals) > 0
            @test minimum(wl_vals) > 190
            @test maximum(wl_vals) < 320

            close(ds)
        end
    end

    @testset "Missing subclass raises clear error" begin
        @test_throws ErrorException MetopDataset(
            GOME2_L1B_FULL_FILE; mdr_subclass = :moon)
    end

    @testset "Earthshine-only variables gated on non-Earthshine subclass" begin
        ds = MetopDataset(GOME2_L1B_FULL_FILE; mdr_subclass = :sun)
        @test_throws ErrorException ds["latitude"]
        @test_throws ErrorException ds["longitude"]
        close(ds)
    end

    @testset "Subclass measurement-mode metadata" begin
        for (sc, expected_mode, expected_units) in [
                (:sun,         "solar_irradiance",   "photon s-1 cm-2 nm-1"),
                (:calibration, "calibration_signal", "photon s-1 cm-2 nm-1 sr-1"),
            ]
            ds = MetopDataset(GOME2_L1B_FULL_FILE; mdr_subclass = sc)
            rad_var = CDM.variable(ds, "radiance_1a")
            @test CDM.attrib(rad_var, "units") == expected_units
            @test CDM.attrib(rad_var, "output_selection_mode") == expected_mode
            close(ds)
        end
    end
end
