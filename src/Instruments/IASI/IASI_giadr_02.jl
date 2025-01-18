# Copyright (c) 2025 EUMETSAT
# License: MIT

# Add IASI Level 2 meta data record.
GIADR_IASI_SND_02_V11_format = joinpath(@__DIR__, "csv_formats/GIADR_IASI_SND_02_V11.csv")

abstract type GIADR_IASI_SND_02 <: GlobalInternalAuxillary end

eval(record_struct_expression(GIADR_IASI_SND_02_V11_format, GIADR_IASI_SND_02))

get_instrument_subclass(::Type{<:GIADR_IASI_SND_02}) = 1

function get_dim_fields(::Type{<:GIADR_IASI_SND_02})
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

function get_iasi_l2_flex_size(giard::GIADR_IASI_SND_02)
    flex_size_prod = Dict{Symbol, Int64}()
    giard_size_fields = get_dim_fields(typeof(giard))

    for k in keys(giard_size_fields)
        value = getfield(giard, k)
        dim_name = giard_size_fields[k]
        flex_size_prod[dim_name] = value
    end

    flex_size_prod[:NEVA_CO] = ceil(Int64, flex_size_prod[:NL_CO] / 2)
    flex_size_prod[:NEVE_CO] = flex_size_prod[:NEVA_CO] * flex_size_prod[:NL_CO]
    flex_size_prod[:NEVA_HNO3] = ceil(Int64, flex_size_prod[:NL_HNO3] / 2)
    flex_size_prod[:NEVE_HNO3] = flex_size_prod[:NEVA_HNO3] * flex_size_prod[:NL_HNO3]
    flex_size_prod[:NEVA_O3] = ceil(Int64, flex_size_prod[:NL_O3] / 2)
    flex_size_prod[:NEVE_O3] = flex_size_prod[:NEVA_O3] * flex_size_prod[:NL_O3]
    flex_size_prod[:NERRT] = Int64(flex_size_prod[:NPCT] * (flex_size_prod[:NPCT] + 1) / 2)
    flex_size_prod[:NERRW] = Int64(flex_size_prod[:NPCW] * (flex_size_prod[:NPCW] + 1) / 2)
    flex_size_prod[:NERRO] = Int64(flex_size_prod[:NPCO] * (flex_size_prod[:NPCO] + 1) / 2)

    return flex_size_prod
end
