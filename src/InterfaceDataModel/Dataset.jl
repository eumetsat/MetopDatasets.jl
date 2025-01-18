# Copyright (c) 2024 EUMETSAT
# License: MIT

struct MetopDataset{R <: DataRecord, L <: RecordLayout} <: CDM.AbstractDataset
    file_pointer::IO
    main_product_header::MainProductHeader
    data_record_layouts::Vector{L}
    data_record_count::Int64
    auto_convert::Bool
    high_precision::Bool
end

"""
    MetopDataset(file_path::AbstractString; auto_convert::Bool = true, high_precision::Bool=false)
    MetopDataset(file_pointer::IO; auto_convert::Bool = true, high_precision::Bool=false)
    MetopDataset(f::Function, file_path::AbstractString; auto_convert::Bool = true, high_precision::Bool=false) 

Load a MetopDataset from a Metop Native binary file or from a `IO` to a Native binary file.
Only the meta data is loaded upon creation and all variables are lazy loaded. 
The variables corresponds to the different fields of the data records in the file.
The attributes have all the information from the main product header in the file.

`auto_convert=true` will automatically convert `MetopDatasets` specific types such as `VInteger` to
common netCDF complaint types such as `Float64`. This will also automatically scale variable where the 
scaling can't be expressed through a simple scale factor e.g. the IASI spectrum where different bands of 
the spectrum have different scaling factors.

Selected fields are converted to `Float32` to save memory. Normally `Float32` is more than sufficient to represent the instrument accuracy. 
Setting `high_precision=true` will in some case convert these variables to `Float64`. 

## Example
```julia-repl
julia> file_path = "test/testData/ASCA_SZR_1B_M03_20230329063300Z_20230329063558Z_N_C_20230329081417Z"
julia> ds = MetopDataset(file_path);
julia>
julia> # display metadata of a variable
julia> ds["latitude"]
latitude (82 × 96)
    Datatype:    Float64 (Int32)
    Dimensions:  xtrack × record
    Attributes:
    description          = Latitude (-90 to 90 deg)
julia>
julia> # load a subset of a variable  
julia> lat_subset = ds["latitude"][1:2,1:3] # load a small subset of latitudes.
2×3 Matrix{Float64}:
    -33.7308  -33.8399  -33.949
    -33.7139  -33.823   -33.9322
julia>
julia> # load entire variable  
julia> lat = ds["latitude"][:,:]
julia>
julia> # close data set
julia> close(ds);
``` 
"""
MetopDataset(file_path::AbstractString; auto_convert::Bool = true, high_precision::Bool = false) = MetopDataset(
    open(file_path, "r"); auto_convert = auto_convert, high_precision = high_precision)

# method to enable `do` syntax.
function MetopDataset(f::Function, file_path::AbstractString;
        auto_convert::Bool = true, high_precision::Bool = false)
    file_pointer = open(file_path, "r")
    try
        ds = MetopDataset(
            file_pointer; auto_convert = auto_convert, high_precision = high_precision)
        return f(ds)
    finally
        close(file_pointer)
    end
end

function MetopDataset(
        file_pointer::IO; auto_convert::Bool = true, high_precision::Bool = false)
    main_product_header = native_read(file_pointer, MainProductHeader)
    record_type = data_record_type(main_product_header)

    # skip secondary header if present
    _skip_sphr(file_pointer, main_product_header.total_sphr)

    record_layouts = _read_record_layouts(file_pointer, main_product_header)
    data_record_layouts = filter(x -> x.record_type == record_type, record_layouts)
    data_record_count = data_record_layouts[end].record_range[end]

    return MetopDataset{record_type, eltype(data_record_layouts)}(file_pointer,
        main_product_header,
        data_record_layouts,
        data_record_count,
        auto_convert,
        high_precision)
end

## Extend CommonDataModel.AbstractDataset interface
function default_varnames(ds::MetopDataset{R}) where {R}
    filed_names_no_record_header = string.(fieldnames(R))[2:end]
    public_fields = (
        "record_start_time", "record_stop_time", filed_names_no_record_header...)
    return public_fields
end

function CDM.varnames(ds::MetopDataset)
    return default_varnames(ds)
end

# needed for CommonDataModel 0.3.6 and older
Base.keys(ds::MetopDataset) = CDM.varnames(ds)

function get_dimensions(R::Type{<:DataRecord},
        data_record_layouts::Vector{<:RecordLayout})::Dict{String, <:Integer}
    return get_dimensions(R)
end

function CDM.dimnames(ds::MetopDataset{R}) where {R}
    names = collect(keys(get_dimensions(R, ds.data_record_layouts)))
    push!(names, RECORD_DIM_NAME)
    return names
end

function CDM.dim(ds::MetopDataset{R}, name::CDM.SymbolOrString) where {R}
    name = string(name)
    if RECORD_DIM_NAME == name
        return ds.data_record_count
    end

    return get_dimensions(R, ds.data_record_layouts)[name]
end

CDM.attribnames(ds::MetopDataset) = string.(fieldnames(MainProductHeader))[2:end] ## Skip record_header

function CDM.attrib(ds::MetopDataset, name::CDM.SymbolOrString)
    val = getfield(ds.main_product_header, Symbol(name))

    if isnothing(val)
        return ""
    elseif !(val isa String)
        return string(val)
    end

    return val
end

Base.close(ds::MetopDataset) = close(ds.file_pointer)

"""
    read_single_record(ds::MetopDataset, record_type::Type{<:Record})
    read_single_record(file_pointer::IO, record_type::Type{<:Record})
    read_single_record(file_path::AbstractString, record_type::Type{<:Record})

Read the n'th record of type `record_type` from the dataset. This can be used to access records that are 
not directly exposed through the `MetopDataset` interface.
"""
read_single_record(ds::MetopDataset, record_type::Type{<:Record}, n::Integer) = read_single_record(
    ds.file_pointer, record_type, n::Integer)

# helper function to test and/or debug dimension
function _valid_dimensions(ds::MetopDataset)
    # result
    no_error_found = true

    # get var names and dims.
    all_vars = CDM.varnames(ds)
    all_dims = CDM.dims(ds)

    # check that dim names of dataset and variables match.
    dims_from_vars = unique(vcat((CDM.dimnames(ds[v]) for v in all_vars)...))
    if sort(dims_from_vars) != sort(CDM.dimnames(ds))
        @warn "mismatch between var dimnames and dataset dimnames."
        @show sort(dims_from_vars)
        @show sort(CDM.dimnames(ds))
        no_error_found = false
    end

    for x in all_vars
        var = ds[x]

        var_dims = CDM.dims(var)
        var_dim_keys = CDM.dimnames(var)
        for i in eachindex(var_dim_keys)
            k = var_dim_keys[i]
            dim_match_array = var_dims[k] == size(var)[i]
            dim_match_ds_dims = var_dims[k] == all_dims[k]
            if !(dim_match_array && dim_match_ds_dims)
                @warn "$x: the $i. dimension $k is $(var_dims[k]) and size is $(size(var))"
                no_error_found = false
            end
        end
    end

    return no_error_found
end

## helper function
function _skip_sphr(file_pointer, n_headers)
    for _ in 1:n_headers
        record_header = native_read(file_pointer, RecordHeader)
        @assert record_header.record_class == get_record_class(SecondaryProductHeader)
        content_size = record_header.record_size - native_sizeof(RecordHeader)
        skip(file_pointer, content_size)
    end
    return nothing
end
