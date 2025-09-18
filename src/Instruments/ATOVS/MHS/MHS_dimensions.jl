function get_dimensions(T::Type{<:MHS_XXX_1B_V10})
    return Dict(
        "thermistor_tm_channels" => 24,
        "lat_lon" => 2,
        "channels_h" => 5,
        "xtrack" => 90,
        "gain_setting" => 3,
        "earth_view_position_flags" => 12,
        "survival_temp" => 3,
        "transmitter_telemetry" => 9,
        "roll_pitch_yaw" => 3,
        "solar_angles" => 4,
        "lunar_angles" => 4
    )
end

function get_field_dimensions(T::Type{<:MHS_XXX_1B_V10},
        field_name::Symbol)::Vector{<:AbstractString}
    if field_name in (MHS_DATA_CAL_QUALITY_NAME, MHS_DATA_CAL_NEDT_NAME)
        return ["channels_h"]
    end

    if !(fieldtype(T, field_name) <: Array)
        return String[]
    end

    array_size = _get_array_size(T, field_name)

    if array_size == (5,)
        return ["channels_h"]
    elseif array_size == (90,)
        return ["xtrack"]
    elseif array_size == (5, 90)
        return ["channels_h", "xtrack"]
    elseif array_size == (2, 90)
        return ["lat_lon", "xtrack"]
    else
        if field_name == :thermistor_tm_channels
            return ["thermistor_tm_channels"]
        elseif field_name == :gain_code
            return ["gain_setting"]
        elseif field_name == :earth_view_position_flag
            return ["earth_view_position_flags"]
        elseif field_name == :survival_temps
            return ["survival_temp"]
        elseif field_name == :transmitter_telem
            return ["transmitter_telemetry"]
        elseif field_name == :euler_angle
            return ["roll_pitch_yaw"]
        elseif field_name == :angular_relation
            return ["solar_angles", "xtrack"]
        elseif field_name == :lunar_angles
            return ["lunar_angles"]
        end
        error("Dimensions not set for $field_type")
    end
end
