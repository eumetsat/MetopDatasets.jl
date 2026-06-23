# Copyright (c) 2024 EUMETSAT
# License: MIT

function get_dimensions(T::Type{<:GOME_XXX_1B})
    dims = OrderedDict(
        "geo_component" => 2,
        "efg" => 3,
        "corner" => 4,
        "band" => 10,
        "stokes_band" => 15,
        "scan_position" => 32,
        "scanner" => 65,
        "pmd_readout" => 256
    )
    # Moon MDR adds 5-element HJKLM lunar pointing vectors (GEO_MOON).
    if T <: Union{GOME_XXX_1B_MOON_V13, GOME_XXX_1B_MOON_V12}
        dims["lunar_point"] = 5
    end
    return dims
end

const GOME2_SIZE_TO_DIMS = Dict{Any, Vector{String}}(
    (2,) => ["geo_component"],
    (3,) => ["efg"],
    (4, 2) => ["corner", "geo_component"],
    (5,) => ["lunar_point"],
    (10,) => ["band"],
    (15,) => ["stokes_band"],
    (15, 32) => ["stokes_band", "scan_position"],
    (32,) => ["scan_position"],
    (32, 2) => ["scan_position", "geo_component"],
    (32, 3) => ["scan_position", "efg"],
    (32, 4, 2) => ["scan_position", "corner", "geo_component"],
    (65,) => ["scanner"],
    (256,) => ["pmd_readout"],
    (:N_GEO_BANDS,) => ["band"]
)

function get_field_dimensions(T::Type{<:GOME_XXX_1B},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    end

    array_size = _get_array_size(T, field_name)
    haskey(GOME2_SIZE_TO_DIMS, array_size) ||
        error("Dimensions not set for field $field_name with size $array_size")
    return deepcopy(GOME2_SIZE_TO_DIMS[array_size])
end
