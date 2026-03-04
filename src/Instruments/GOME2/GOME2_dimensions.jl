# Copyright (c) 2024 EUMETSAT
# License: MIT

function get_dimensions(T::Type{<:GOME_XXX_1B})
    return OrderedDict(
        "geo_component" => 2,
        "efg" => 3,
        "corner" => 4,
        "band" => 10,
        "stokes_band" => 15,
        "scan_position" => 32,
        "scanner" => 65,
        "pmd_readout" => 256
    )
end

function get_field_dimensions(T::Type{<:GOME_XXX_1B},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    end

    array_size = _get_array_size(T, field_name)

    if array_size == (10,)
        return String["band"]
    elseif array_size == (15,)
        return String["stokes_band"]
    elseif array_size == (15, 32)
        return String["stokes_band", "scan_position"]
    elseif array_size == (32,)
        return String["scan_position"]
    elseif array_size == (32, 2)
        return String["scan_position", "geo_component"]
    elseif array_size == (32, 3)
        return String["scan_position", "efg"]
    elseif array_size == (32, 4, 2)
        return String["scan_position", "corner", "geo_component"]
    elseif array_size == (4, 2)
        return String["corner", "geo_component"]
    elseif array_size == (2,)
        return String["geo_component"]
    elseif array_size == (65,)
        return String["scanner"]
    elseif array_size == (256,)
        return String["pmd_readout"]
    elseif array_size == (3,)
        return String["efg"]
    elseif array_size == (:N_GEO_BANDS,)
        return String["band"]
    else
        error("Dimensions not set for field $field_name with size $array_size")
    end
end
