# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    get_description(T::Type{<:BinaryRecord}, field::Symbol)::AbstractString

Get the description for a given field in the `BinaryRecord`
# Example
```julia-repl
julia> get_description(ASCA_SZR_1B_V13, :sigma0_trip)
"Sigma0 triplet, re-sampled to swath grid, for 3 beams (fore, mid, aft) "
```
"""
function get_description(T::Type{<:BinaryRecord}, field::Symbol)::AbstractString
    if field == :record_start_time
        return "Record header start time"
    elseif field == :record_stop_time
        return "Record header stop time"
    end

    return get_description(T)[field]
end
"""
    get_scale_factor(T::Type{<:BinaryRecord}, field::Symbol)::Union{Number,Nothing}

get the `scale_factor` for a given field in the `BinaryRecord`. The variable can late be scaled from 
integer to float by dividing with `10^scale_factor`. Returns `nothing` if no scale factor is set. 
# Example
```julia-repl
julia> get_scale_factor(ASCA_SZR_1B_V13, :sigma0_trip) 
6
```
"""
get_scale_factor(T::Type{<:BinaryRecord}, field::Symbol)::Union{Number, Nothing} = get_scale_factor(T)[field]

"""
    get_raw_format_dim(T::Type{<:BinaryRecord}, field::Symbol)::NTuple{4, Int64}
    
Get the dimensions of the field as defined in the record format specification.
# Example
```julia-repl
julia> get_raw_format_dim(ASCA_SZR_1B_V13, :sigma0_trip)
(3, 82, 1, 1)
```
"""
get_raw_format_dim(T::Type{<:BinaryRecord}, field::Symbol) = get_raw_format_dim(T)[field]

"""
    data_record_type(header::MainProductHeader)::Type

Get the type of data record based on the main product header
# Example
```julia-repl
julia> file_pointer = open("ASCA_SZO_1B_M03_20230329063300Z_20230329063556Z_N_C_20230329081417Z")
julia> main_header = MetopDatasets.native_read(file_pointer, MainProductHeader)
julia> data_record_type(main_header)
ASCA_SZO_1B_V13
```
"""
data_record_type(header::MainProductHeader)::Type = data_record_type(header,
    Val(Symbol(header.product_name[1:11])))

### Interface must be implemented for each BinaryRecord type

# get_description and get_scale_factor are automatically defined by record_struct_expression
get_description(T::Type{<:BinaryRecord}) = error("Method missing for $T")
get_scale_factor(T::Type{<:BinaryRecord}) = error("Method missing for $T")
get_raw_format_dim(T::Type{<:BinaryRecord}) = error("Method missing for $T")

# add docs
# Record and RecordSubType without arrays are automatically fixed sized.
fixed_size(T::Type{<:BinaryRecord}) = !any(x -> x <: AbstractArray, fieldtypes(T))
fixed_size(T::Type{<:RecordSubType}) = !any(x -> x <: AbstractArray, fieldtypes(T))
function fixed_size(T::Type{<:BinaryRecord}, fieldname::Symbol)
    if (fieldname == :record_start_time) || (fieldname == :record_stop_time)
        return true
    end
    if fieldtype(T, fieldname) <: AbstractArray
        return !any(x -> x isa Symbol, get_raw_format_dim(T, fieldname))
    else
        return true
    end
end

# add docs
get_dim_fields(T::Type{<:BinaryRecord}) = error("Method missing for $T")

# data_record_type must be defined manually
function data_record_type(header::MainProductHeader, product_type::Val{T}) where {T}
    return error("Method missing for $T")
end

# get_dimensions and get_field_dimensions should be implemented manually but fallback methods exits 
"""
    get_dimensions(T::Type{<:BinaryRecord})::Dict{String, <:Integer}

Get the the named dimensions in a BinaryRecord and their length.
# Example
```julia-repl
julia> get_dimensions(ASCA_SZR_1B_V13)
Dict{String, Int64} with 2 entries:
  "num_band" => 3
  "xtrack"   => 82
```
"""
function get_dimensions(T::Type{<:BinaryRecord})::Dict{String, <:Integer}
    # find all array fields size
    array_sizes = [MetopDatasets._get_array_size(T, n)
                   for n in fieldnames(T) if fieldtype(T, n) <: Array]

    # get all unique dimensions
    dims = reduce(vcat, [[t...] for t in array_sizes])
    unique!(dims)
    sort!(dims)

    dims_dict = Dict{String, Int64}()
    for i in eachindex(dims)
        dims_dict["dim_$i"] = dims[i]
    end

    return dims_dict
end

# fall back method
"""
    get_field_dimensions(T::Type{<:BinaryRecord}, field::Symbol)::Vector{<:AbstractString}

Get the named dimensions of a field in a BinaryRecord
# Example
```julia-repl
julia> get_field_dimensions(ASCA_SZR_1B_V13, :sigma0_trip)
["num_band", "xtrack"]
```
"""
function get_field_dimensions(T::Type{<:BinaryRecord}, field::Symbol)::Vector{String}
    field_type = fieldtype(T, field)
    if !(field_type <: Array)
        return String[]
    end

    dimensions = get_dimensions(T)
    dimension_names = String[]

    for d in _get_array_size(T, field)
        d_name = only([dim_name for (dim_name, dim_val) in dimensions if dim_val == d])
        push!(dimension_names, d_name)
    end

    return dimension_names
end

### default missing values
function get_missing_value(T::Type{<:Record}, field::Symbol)
    return get_missing_value(T, _get_field_eltype(T, field))
end

# default is nothing
get_missing_value(T::Type{<:Record}, field_type::Type) = nothing

get_missing_value(::Type{<:Record}, field_type::Type{<:Unsigned}) = typemax(field_type)
get_missing_value(::Type{<:Record}, field_type::Type{<:Signed}) = typemin(field_type)
