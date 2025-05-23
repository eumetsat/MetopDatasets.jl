# Copyright (c) 2025 EUMETSAT
# License: MIT

# Add IASI Level 2 meta data record.
const IASI_L2_V10_03_PRESSURE_DIM = "n_o3_profiles"

abstract type GIADR_IASI_SND_02 <: GlobalInternalAuxillary end

const GIADR_IASI_SND_02_V11_format = @path joinpath(@__DIR__, "csv_formats/GIADR_IASI_SND_02_V11.csv")
const GIADR_IASI_SND_02_V10_format = @path joinpath(@__DIR__, "csv_formats/GIADR_IASI_SND_02_V10.csv")

eval(record_struct_expression(GIADR_IASI_SND_02_V11_format, GIADR_IASI_SND_02))
eval(record_struct_expression(GIADR_IASI_SND_02_V10_format, GIADR_IASI_SND_02))

get_instrument_subclass(::Type{<:GIADR_IASI_SND_02}) = 1

function get_giard_varnames(::Type{GIADR_IASI_SND_02_V11})
    return (
        :pressure_levels_temp,
        :pressure_levels_humidity,
        :pressure_levels_ozone,
        :surface_emissivity_wavelengths,
        :forli_layer_heights_co,
        :forli_layer_heights_hno3,
        :forli_layer_heights_o3,
        :brescia_altitudes_so2)
end

function get_giard_varnames(::Type{GIADR_IASI_SND_02_V10})
    return (
        :pressure_levels_temp,
        :pressure_levels_ozone,
        :pressure_levels_humidity,
        :surface_emissivity_wavelengths)
end

function get_flexible_dim_fields(::Type{GIADR_IASI_SND_02_V11})
    return Dict(
        :num_temperature_pcs => :NPCT,
        :num_pressure_levels_temp => :NLT,
        :num_ozone_pcs => :NPCO,
        :num_pressure_levels_ozone => :NLO,
        :forli_num_layers_co => :NL_CO,
        :num_water_vapour_pcs => :NPCW,
        :num_pressure_levels_humidity => :NLQ,
        :brescia_num_altitudes_so2 => :NL_SO2,
        :num_surface_emissivity_wavelengths => :NEW,
        :forli_num_layers_hno3 => :NL_HNO3,
        :forli_num_layers_o3 => :NL_O3)
end

function get_flexible_dim_fields(::Type{GIADR_IASI_SND_02_V10})
    return Dict(
        :num_pressure_levels_temp => :NLT,
        :num_pressure_levels_ozone => :NLO,
        :num_pressure_levels_humidity => :NLQ,
        :num_surface_emissivity_wavelengths => :NEW)
end

function get_iasi_l2_flex_size(giard::T) where {T <: GIADR_IASI_SND_02}
    flex_size_prod = Dict{Symbol, Int64}()
    giard_size_fields = get_flexible_dim_fields(typeof(giard))

    for k in keys(giard_size_fields)
        value = getfield(giard, k)
        dim_name = giard_size_fields[k]
        flex_size_prod[dim_name] = value
    end

    # computed dimensions
    _add_computed_dimension!(flex_size_prod, T)
    return flex_size_prod
end

function _add_computed_dimension!(flex_size_prod::Dict, ::Type{GIADR_IASI_SND_02_V11})
    flex_size_prod[:NEVA_CO] = ceil(Int64, flex_size_prod[:NL_CO] / 2)
    flex_size_prod[:NEVE_CO] = flex_size_prod[:NEVA_CO] * flex_size_prod[:NL_CO]
    flex_size_prod[:NEVA_HNO3] = ceil(Int64, flex_size_prod[:NL_HNO3] / 2)
    flex_size_prod[:NEVE_HNO3] = flex_size_prod[:NEVA_HNO3] * flex_size_prod[:NL_HNO3]
    flex_size_prod[:NEVA_O3] = ceil(Int64, flex_size_prod[:NL_O3] / 2)
    flex_size_prod[:NEVE_O3] = flex_size_prod[:NEVA_O3] * flex_size_prod[:NL_O3]
    flex_size_prod[:NERRT] = Int64(flex_size_prod[:NPCT] * (flex_size_prod[:NPCT] + 1) / 2)
    flex_size_prod[:NERRW] = Int64(flex_size_prod[:NPCW] * (flex_size_prod[:NPCW] + 1) / 2)
    flex_size_prod[:NERRO] = Int64(flex_size_prod[:NPCO] * (flex_size_prod[:NPCO] + 1) / 2)
    return nothing
end

function _add_computed_dimension!(flex_size_prod::Dict, ::Type{GIADR_IASI_SND_02_V10})
    return nothing
end

function get_field_dimensions(T::Type{GIADR_IASI_SND_02_V11}, field::Symbol)
    return [string(get_raw_format_dim(T)[field][1])]
end

function get_field_dimensions(T::Type{GIADR_IASI_SND_02_V10}, field::Symbol)
    if field == :pressure_levels_ozone
        return [IASI_L2_V10_03_PRESSURE_DIM, string(get_raw_format_dim(T)[field][2])]
    end

    return [string(get_raw_format_dim(T)[field][1])]
end
