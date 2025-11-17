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
get_scale_factor(T::Type{<:BinaryRecord},
    field::Symbol)::Union{Number, Nothing} = get_scale_factor(T)[field]

"""
    get_raw_format_dim(T::Type{<:BinaryRecord}, field::Symbol)
    
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

"""
    fixed_size(T::Type{<:BinaryRecord})::Bool
    fixed_size(T::Type{<:BinaryRecord}, fieldname::Symbol)::Bool

Get if the data record has a binary fixed size. This is often used as a trait via the "julia Holy Traits Pattern"
`fieldname` is used to check if a specific field has a fixed binary size.
"""
function fixed_size(T::Type{<:BinaryRecord}, fieldname::Symbol)
    if fixed_size(T) || (fieldname == :record_start_time) ||
       (fieldname == :record_stop_time)
        return true
    end

    if fieldtype(T, fieldname) <: AbstractArray
        return !any(x -> x isa Symbol, get_raw_format_dim(T, fieldname))
    else
        return true
    end
end

"""
    fixed_size_in_file(T::Type{<:BinaryRecord}, fieldname::Symbol)::Bool

Check if the field have a constant size in a product. Return false if the field size
can vary within a single file.
"""
function fixed_size_in_file(T::Type{<:BinaryRecord}, fieldname::Symbol)
    if fixed_size(T, fieldname)
        return true
    end

    field_dims = get_raw_format_dim(T, fieldname)
    flexible_dims_in_record = values(get_flexible_dim_fields(T))
    return !any(dim in flexible_dims_in_record for dim in field_dims)
end

### Interface must be implemented for each BinaryRecord type

# get_description, get_scale_factor, get_raw_format_dim and fixed_size are automatically defined by record_struct_expression
get_description(T::Type{<:BinaryRecord}) = error("Method missing for $T")
get_scale_factor(T::Type{<:BinaryRecord}) = error("Method missing for $T")
get_raw_format_dim(T::Type{<:BinaryRecord}) = error("Method missing for $T")

# add fixed_size fall back methods for records
fixed_size(T::Type{<:RecordSubType}) = !any(x -> x <: AbstractArray, fieldtypes(T))
fixed_size(T::Type{<:BinaryRecord}) = !any(x -> x <: AbstractArray, fieldtypes(T))

# data_record_type must be defined manually
function data_record_type(header::MainProductHeader, product_type::Val{T}) where {T}
    return error("Method missing for $T")
end

# get_dimensions and get_field_dimensions should be implemented manually but fallback methods exits 
"""
    get_dimensions(T::Type{<:BinaryRecord})::OrderedDict{String, <:Integer}

Get the the named dimensions in a BinaryRecord and their length.
# Example
```julia-repl
julia> get_dimensions(ASCA_SZR_1B_V13)
OrderedDict{String, Int64} with 2 entries:
  "num_band" => 3
  "xtrack"   => 82
```
"""
function get_dimensions(T::Type{<:BinaryRecord})::OrderedDict{String, <:Integer}
    # find all array fields size
    array_sizes = [MetopDatasets._get_array_size(T, n)
                   for n in fieldnames(T) if fieldtype(T, n) <: Array]

    # get all unique dimensions
    dims = reduce(vcat, [[t...] for t in array_sizes])
    unique!(dims)
    sort!(dims)

    dims_dict = OrderedDict{String, Int64}()
    for i in eachindex(dims)
        dims_dict["dim_$i"] = dims[i]
    end

    return dims_dict
end

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

"""
    get_missing_value(T::Type{<:Record}, field::Symbol)

Get the value representing `missing` for the field. Default values are implemented for `Integers` but 
they can be overwritten for specific record types to account for different conventions.
"""
function get_missing_value(T::Type{<:Record}, field::Symbol)
    return get_missing_value(T, _get_field_eltype(T, field), field)
end

# default is nothing
get_missing_value(T::Type{<:Record}, field_type::Type, field::Symbol) = nothing
# default values based on ASCAT
function get_missing_value(::Type{<:Record}, field_type::Type{<:Unsigned}, field::Symbol)
    return typemax(field_type)
end
function get_missing_value(::Type{<:Record}, field_type::Type{<:Signed}, field::Symbol)
    return typemin(field_type)
end

### Methods needed for flexible record types  ####

"""
    get_flexible_dim_fields(T::Type{<:BinaryRecord})::AbstractDict{Symbol,Symbol}

Get a dictionary with field names as key and the corresponding flexible dim as value. 
Only fields representing a flexible dim is included. Must be implemented for Records containing 
flexible dim values.

# Example
```julia-repl
julia> get_flexible_dim_fields(IASI_SND_02)
OrderedDict{Symbol, Symbol} with 4 entries:
  :co_nbr   => :CO_NBR
  :o3_nbr   => :O3_NBR
  :nerr     => :NERR
  :hno3_nbr => :HNO3_NBR
```
"""
get_flexible_dim_fields(T::Type{<:BinaryRecord}) = error("Method missing for $T")

"""
    _get_flexible_dims_file(file_pointer::IO, T::Type{<:BinaryRecord}) 

Read the flexible types from a product. Note that the `IO` position is not changed by
calling the function
"""
function _get_flexible_dims_file(file_pointer::IO, T::Type{<:BinaryRecord})
    return OrderedDict{Symbol, Int64}()
end
