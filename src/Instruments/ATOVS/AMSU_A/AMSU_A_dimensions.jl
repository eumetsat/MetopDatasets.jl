# Copyright (c) 2025 EUMETSAT
# License: MIT

function get_dimensions(T::Type{<:AMSA_XXX_1B})
    return OrderedDict(
        "lat_lon" => 2,
        "channels" => 15,
        "xtrack" => 30,
        "roll_pitch_yaw" => 3,
        "solar_angles" => 4,
        "data_calibration" => 16,
        "calibration_coefficients" => 3,
        "reflector_readings" => 2,
        "temperature_dim2" => 2,
        "temperature_dim3" => 3,
        "temperature_dim5" => 5,
        "temperature_dim6" => 6,
        "temperature_dim7" => 7
    )
end

function get_field_dimensions(T::Type{<:AMSA_XXX_1B},
        field_name::Symbol)::Vector{<:AbstractString}
    if field_name in (DATA_CAL_QUALITY_NAME, DATA_CAL_NEDT_NAME)
        return ["data_calibration"]
    end

    if !(fieldtype(T, field_name) <: Array)
        return String[]
    end

    array_size = _get_array_size(T, field_name)

    if array_size == (30,)
        return ["xtrack"]
    elseif array_size == (15, 30)
        return ["channels", "xtrack"]
    elseif array_size == (3, 15)
        return ["calibration_coefficients", "channels"]
    elseif array_size == (2, 30)
        if field_name == :earth_location
            return ["lat_lon", "xtrack"]
        else
            return ["reflector_readings", "xtrack"]
        end
    else
        if field_name == :euler_angle
            return ["roll_pitch_yaw"]
        elseif field_name == :angular_relation
            return ["solar_angles", "xtrack"]
        elseif startswith(string(field_name), "reflector")
            return ["reflector_readings"]
        elseif only(array_size) in (2, 3, 5, 6, 7)
            l = only(array_size)
            return ["temperature_dim$l"]
        end
        error("Dimensions not set for $field_type")
    end
end
