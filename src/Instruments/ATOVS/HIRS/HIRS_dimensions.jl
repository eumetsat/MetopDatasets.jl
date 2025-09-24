# Copyright (c) 2025 EUMETSAT
# License: MIT

function get_dimensions(T::Type{<:HIRS_XXX_1B})
    return Dict(
        "lat_lon" => 2,
        "channels" => 20,
        "xtrack" => 56,
        "transmitter_telemetry" => 9,
        "roll_pitch_yaw" => 3,
        "solar_angles" => 4,
        "flags" => 8,
        "analog_data" => 16
    )
end

function get_field_dimensions(T::Type{<:HIRS_XXX_1B},
        field_name::Symbol)::Vector{<:AbstractString}
    if field_name in (DATA_CAL_QUALITY_NAME, DATA_CAL_NEDT_NAME)
        return ["channels"]
    elseif field_name == ELEMENT_RAD_DATA_NAME
        return ["channels", "xtrack"]
    elseif field_name == ELEMENT_RAD_HEADER_NAME
        return ["xtrack"]
    elseif field_name == ELEMENT_FLAG_DATA_NAME
        return ["channels", "flags"]
    elseif field_name == ELEMENT_FLAG_HEADER_NAME
        return ["flags"]
    end

    if !(fieldtype(T, field_name) <: Array)
        return String[]
    end

    array_size = _get_array_size(T, field_name)

    if array_size == (20,)
        return ["channels"]
    elseif array_size == (56,)
        return ["xtrack"]
    elseif array_size == (2, 56)
        return ["lat_lon", "xtrack"]
    else
        if field_name == :analog_data
            return ["analog_data"]
        elseif field_name == :euler_angle
            return ["roll_pitch_yaw"]
        elseif field_name == :angular_relation
            return ["solar_angles", "xtrack"]
        end
        error("Dimensions not set for $field_type")
    end
end
