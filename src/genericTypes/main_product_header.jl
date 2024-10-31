# Copyright (c) 2024 EUMETSAT
# License: MIT

const DATE_FORMAT_PRODUCT_HEADER = DateFormat("yyyymmddHHMMSS");
const DATE_FORMAT_PRODUCT_HEADER_LONG = DateFormat("yyyymmddHHMMSSsss");

struct MainProductHeader <: Header
    record_header::RecordHeader
    product_name::String
    parent_product_name_1::String
    parent_product_name_2::String
    parent_product_name_3::String
    parent_product_name_4::String
    instrument_id::String
    instrument_model::String
    product_type::String
    processing_level::String
    spacecraft_id::String
    sensing_start::DateTime
    sensing_end::DateTime
    sensing_start_theoretical::DateTime
    sensing_end_theoretical::DateTime
    processing_centre::String
    processor_major_version::Int64
    processor_minor_version::Int64
    format_major_version::Int64
    format_minor_version::Int64
    processing_time_start::DateTime
    processing_time_end::DateTime
    processing_mode::String
    disposition_mode::String
    receiving_ground_station::String
    receive_time_start::Union{DateTime, Nothing}
    receive_time_end::Union{DateTime, Nothing}
    orbit_start::Int64
    orbit_end::Int64
    actual_product_size::Int64
    state_vector_time::DateTime
    semi_major_axis::Int64
    eccentricity::Int64
    inclination::Int64
    perigee_argument::Int64
    right_ascension::Int64
    mean_anomaly::Int64
    x_position::Int64
    y_position::Int64
    z_position::Int64
    x_velocity::Int64
    y_velocity::Int64
    z_velocity::Int64
    earth_sun_distance_ratio::Int64
    location_tolerance_radial::Int64
    location_tolerance_crosstrack::Int64
    location_tolerance_alongtrack::Int64
    yaw_error::Int64
    roll_error::Int64
    pitch_error::Int64
    subsat_latitude_start::Int64
    subsat_longitude_start::Int64
    subsat_latitude_end::Int64
    subsat_longitude_end::Int64
    leap_second::Int64
    leap_second_utc::Union{Nothing, DateTime}
    total_records::Int64
    total_mphr::Int64
    total_sphr::Int64
    total_ipr::Int64
    total_geadr::Int64
    total_giadr::Int64
    total_veadr::Int64
    total_viadr::Int64
    total_mdr::Int64
    count_degraded_inst_mdr::Int64
    count_degraded_proc_mdr::Int64
    count_degraded_inst_mdr_blocks::Int64
    count_degraded_proc_mdr_blocks::Int64
    duration_of_product::Int64
    milliseconds_of_data_present::Int64
    milliseconds_of_data_missing::Int64
    subsetted_product::String
end

_parse_mphr_string(T::Type{String}, str::AbstractString) = String(str)
_parse_mphr_string(T::Type{<:Number}, str::AbstractString) = parse(T, str)

function _parse_mphr_string(::Type{DateTime}, str::AbstractString)::DateTime
    if length(str) == 18
        return DateTime(str[1:17], DATE_FORMAT_PRODUCT_HEADER_LONG)
    else
        return DateTime(str[1:14], DATE_FORMAT_PRODUCT_HEADER)
    end
end

function _parse_mphr_string(::Type{Union{Nothing, DateTime}}, str::AbstractString)
    if isnothing(tryparse(Int64, str[1:2]))
        return nothing
    else
        return _parse_mphr_string(DateTime, str)
    end
end

native_sizeof(T::Type{MainProductHeader}) = 3307

function native_read(io::IO, T::Type{MainProductHeader})::MainProductHeader
    record_header = native_read(io, RecordHeader)

    # read the content
    content_size = native_sizeof(MainProductHeader) - native_sizeof(RecordHeader)
    main_header_content = Array{UInt8}(undef, content_size)
    read!(io, main_header_content)

    #extract the values as string
    main_header_content = String(ntoh.(main_header_content))
    main_header_content = split(main_header_content, "\n")
    filter!(x -> !isempty(x), main_header_content)
    string_values = [strip(split(row, '=')[2]) for row in main_header_content]

    #parse the values
    values = _parse_mphr_string.(fieldtypes(MainProductHeader)[2:end], string_values)

    return MainProductHeader(record_header, values...)
end
