# Copyright (c) 2024 EUMETSAT
# License: MIT

########### SZR ###########
# Note, there is probably a better way to handle the path. @__DIR__ is a bit of a hack
#  @__DIR__ ensure that the path is relative to the location of this file.
const ASCA_SZR_1B_V13_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZR_1B_V13.csv")
const ASCA_SZR_1B_V12_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZR_1B_V12.csv")
const ASCA_SZR_1B_V11_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZR_1B_V11.csv")

abstract type ASCA_SZR_1B <: DataRecord end
# create data structure, add description and scale factors
eval(record_struct_expression(ASCA_SZR_1B_V13_format, ASCA_SZR_1B))
eval(record_struct_expression(ASCA_SZR_1B_V12_format, ASCA_SZR_1B))
eval(record_struct_expression(ASCA_SZR_1B_V11_format, ASCA_SZR_1B))

# Named dimensions must be added manual since they are not part of the normal format
get_dimensions(T::Type{<:ASCA_SZR_1B}) = Dict("num_band" => 3, "xtrack" => 82)

function get_field_dimensions(T::Type{<:ASCA_SZR_1B},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    elseif _get_array_size(T, field_name) == (82,)
        return String["xtrack"]
    elseif _get_array_size(T, field_name) == (3, 82)
        return String["num_band", "xtrack"]
    else
        error("Dimensions not set for $field_type")
    end
end

function data_record_type(header::MainProductHeader, product_type::Val{:ASCA_SZR_1B})::Type
    if header.format_major_version == 13
        return ASCA_SZR_1B_V13
    elseif header.format_major_version == 12
        return ASCA_SZR_1B_V12
    elseif header.format_major_version == 11
        return ASCA_SZR_1B_V11
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

########### SZO ###########
abstract type ASCA_SZO_1B <: DataRecord end

const ASCA_SZO_1B_V13_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZO_1B_V13.csv")
const ASCA_SZO_1B_V12_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZO_1B_V12.csv")
const ASCA_SZO_1B_V11_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZO_1B_V11.csv")

eval(record_struct_expression(ASCA_SZO_1B_V13_format, ASCA_SZO_1B))
eval(record_struct_expression(ASCA_SZO_1B_V12_format, ASCA_SZO_1B))
eval(record_struct_expression(ASCA_SZO_1B_V11_format, ASCA_SZO_1B))

get_dimensions(T::Type{<:ASCA_SZO_1B}) = Dict("num_band" => 3, "xtrack" => 42)
function get_field_dimensions(T::Type{<:ASCA_SZO_1B},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    elseif _get_array_size(T, field_name) == (42,)
        return String["xtrack"]
    elseif _get_array_size(T, field_name) == (3, 42)
        return String["num_band", "xtrack"]
    else
        error("Dimensions not set for $field_type")
    end
end

function data_record_type(header::MainProductHeader, product_type::Val{:ASCA_SZO_1B})::Type
    if header.format_major_version == 13
        return ASCA_SZO_1B_V13
    elseif header.format_major_version == 12
        return ASCA_SZO_1B_V12
    elseif header.format_major_version == 11
        return ASCA_SZO_1B_V11
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

########### SZO ###########
abstract type ASCA_SZF_1B <: DataRecord end

const ASCA_SZF_1B_V13_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZF_1B_V13.csv")
const ASCA_SZF_1B_V12_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZF_1B_V12.csv")
const ASCA_SZF_1B_V11_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SZF_1B_V11.csv")

eval(record_struct_expression(ASCA_SZF_1B_V13_format, ASCA_SZF_1B))
eval(record_struct_expression(ASCA_SZF_1B_V12_format, ASCA_SZF_1B))
eval(record_struct_expression(ASCA_SZF_1B_V11_format, ASCA_SZF_1B))

get_dimensions(T::Type{<:ASCA_SZF_1B}) = Dict("xtrack" => 192)
function get_field_dimensions(T::Type{<:ASCA_SZF_1B},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    elseif _get_array_size(T, field_name) == (192,)
        return String["xtrack"]
    else
        error("Dimensions not set for $field_type")
    end
end

# Dimensions are different for V11
get_dimensions(T::Type{ASCA_SZF_1B_V11}) = Dict("xtrack" => 256, "beam" => 6)
function get_field_dimensions(T::Type{ASCA_SZF_1B_V11},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    elseif _get_array_size(T, field_name) == (256,)
        return String["xtrack"]
    elseif _get_array_size(T, field_name) == (6,)
        return String["beam"]
    elseif _get_array_size(T, field_name) == (256, 6)
        return String["xtrack", "beam"]
    else
        error("Dimensions not set for $field_type")
    end
end

function data_record_type(header::MainProductHeader, product_type::Val{:ASCA_SZF_1B})::Type
    if header.format_major_version == 13
        return ASCA_SZF_1B_V13
    elseif header.format_major_version == 12
        return ASCA_SZF_1B_V12
    elseif header.format_major_version == 11
        return ASCA_SZF_1B_V11
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

########### SMR ###########
abstract type ASCA_SMR_02 <: DataRecord end

const ASCA_SMR_02_V12_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SMR_02_V12.csv")

eval(record_struct_expression(ASCA_SMR_02_V12_format, ASCA_SMR_02))

get_dimensions(T::Type{<:ASCA_SMR_02}) = Dict("num_band" => 3, "xtrack" => 82)
function get_field_dimensions(T::Type{<:ASCA_SMR_02},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    elseif _get_array_size(T, field_name) == (82,)
        return String["xtrack"]
    elseif _get_array_size(T, field_name) == (3, 82)
        return String["num_band", "xtrack"]
    else
        error("Dimensions not set for $field_type")
    end
end

function data_record_type(header::MainProductHeader, product_type::Val{:ASCA_SMR_02})::Type
    if header.format_major_version == 12
        return ASCA_SMR_02_V12
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

########### SMO ###########
abstract type ASCA_SMO_02 <: DataRecord end

const ASCA_SMO_02_V12_format = @path joinpath(@__DIR__, "csv_formats/ASCA_SMO_02_V12.csv")

eval(record_struct_expression(ASCA_SMO_02_V12_format, ASCA_SMO_02))

get_dimensions(T::Type{<:ASCA_SMO_02}) = Dict("num_band" => 3, "xtrack" => 42)
function get_field_dimensions(T::Type{<:ASCA_SMO_02},
        field_name::Symbol)::Vector{<:AbstractString}
    if !(fieldtype(T, field_name) <: Array)
        return String[]
    elseif _get_array_size(T, field_name) == (42,)
        return String["xtrack"]
    elseif _get_array_size(T, field_name) == (3, 42)
        return String["num_band", "xtrack"]
    else
        error("Dimensions not set for $field_type")
    end
end

function data_record_type(header::MainProductHeader, product_type::Val{:ASCA_SMO_02})::Type
    if header.format_major_version == 12
        return ASCA_SMO_02_V12
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end
