# Copyright (c) 2024 EUMETSAT
# License: MIT

function get_dimensions(T::Type{<:IASI_XXX_1C})
    return Dict(
        "corner_cube_direction" => 2,
        "lon_lat" => 2,
        "line_column" => 2,
        "zenith_azimuth" => 2,
        "band" => 3,
        "sounder_pixel" => 4,
        "avhrr_channel" => 6,
        "fov_class" => 7,
        "subgrid_imager_pixel" => 25,
        "xtrack" => 30,
        "integrated_imager_column" => 64,
        "integrated_imager_line" => 64,
        "avhrr_image_column" => 100,
        "avhrr_image_line" => 100,
        "eigenvalue" => 100,
        "spectral" => 8700
    )
end

function get_field_dimensions(T::Type{<:IASI_XXX_1C},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    end

    array_size = _get_array_size(T, field_name)

    if array_size == (2, 4, 30)
        if field_name == :ggeosondloc
            return ["lon_lat", "sounder_pixel", "xtrack"]
        elseif field_name == :gepslociasiavhrr_iasi
            return ["line_column", "sounder_pixel", "xtrack"]
        else
            return ["zenith_azimuth", "sounder_pixel", "xtrack"]
        end
    elseif array_size == (2, 25, 30)
        if field_name == :gepslociasiavhrr_iis
            return ["line_column", "subgrid_imager_pixel", "xtrack"]
        else
            return ["zenith_azimuth", "subgrid_imager_pixel", "xtrack"]
        end
    elseif array_size == (30,)
        return ["xtrack"]
    elseif array_size == (2,)
        return ["corner_cube_direction"]
    elseif array_size == (64, 64, 30)
        return ["integrated_imager_column", "integrated_imager_line", "xtrack"]
    elseif array_size == (3, 4, 30)
        return ["band", "sounder_pixel", "xtrack"]
    elseif array_size == (4, 30)
        return ["sounder_pixel", "xtrack"]
    elseif array_size == (8700, 4, 30)
        return ["spectral", "sounder_pixel", "xtrack"]
    elseif array_size == (2, 100)
        return ["corner_cube_direction", "eigenvalue"]
    elseif array_size == (6,)
        return ["avhrr_channel"]
    elseif array_size == (7, 4, 30)
        return ["fov_class", "sounder_pixel", "xtrack"]
    elseif array_size == (6, 7, 4, 30)
        return ["avhrr_channel", "fov_class", "sounder_pixel", "xtrack"]
    elseif array_size == (100, 100, 30)
        return ["avhrr_image_column", "avhrr_image_line", "xtrack"]
    elseif array_size == (7, 30)
        return ["fov_class", "xtrack"]
    else
        error("Dimensions not set for $field_type")
    end
end

############  IASI_SND_02  ################

function _get_fixed_dimensions(T::Type{IASI_SND_02_V11})
    dimensions_dict = Dict(
        "lat_lon" => 2,
        "cloud_formations" => 3,
        "solar_sat_zenith_azimuth" => 4,
        "xtrack_sounder_pixels" => 120
    )
    return dimensions_dict
end

function _get_fixed_dimensions(T::Type{IASI_SND_02_V10})
    dimensions_dict = Dict(
        "lat_lon" => 2,
        "cloud_formations" => 3,
        "solar_sat_zenith_azimuth" => 4,
        "xtrack_sounder_pixels" => 120,
        IASI_L2_V10_03_PRESSURE_DIM => 2,
        "n_surface_temperatures" => 2,
        "error_data_dims" => 2
    )
    return dimensions_dict
end

function get_dimensions(T::Type{<:IASI_SND_02},
        data_record_layouts::Vector{<:RecordLayout})::Dict{String, <:Integer}
    dimensions_dict = Dict{String, Integer}()
    layout = only(data_record_layouts)

    for d in keys(layout.flexible_dims_file)
        dimensions_dict[string(d)] = layout.flexible_dims_file[d]
    end

    merge!(dimensions_dict, _get_fixed_dimensions(T))

    return dimensions_dict
end

function get_field_dimensions(
        T::Type{<:IASI_SND_02}, field_name::Symbol)
    res = String[]

    if !(fieldtype(T, field_name) <: Array)
        return res
    end

    dimension_dict = _get_fixed_dimensions(T)
    array_size = _get_array_size(T, field_name)
    flexible_dims_names = values(get_flexible_dim_fields(T))

    for d in array_size
        if d isa Symbol
            if d in flexible_dims_names
                # replace flexible dims with "xtrack_sounder_pixels"
                push!(res, "xtrack_sounder_pixels")
            else
                push!(res, string(d))
            end
        elseif T <: IASI_SND_02_V10 && d == 2
            if field_name == :pressure_levels_ozone
                push!(res, IASI_L2_V10_03_PRESSURE_DIM)
            elseif field_name == :surface_temperature
                push!(res, "n_surface_temperatures")
            elseif field_name == :data_sizes
                push!(res, "error_data_dims")
            else
                push!(res, "lat_lon")
            end
        else
            names = [dim_name for (dim_name, dim_val) in dimension_dict if dim_val == d]
            push!(res, string(first(names)))
        end
    end
    return res
end
