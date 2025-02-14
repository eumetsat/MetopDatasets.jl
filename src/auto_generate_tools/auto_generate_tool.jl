# Copyright (c) 2024 EUMETSAT
# License: MIT

const TYPE_NAMES = Dict("rec_head" => RecordHeader,
    "short cds time" => ShortCdsTime,
    "long cds time" => LongCdsTime,
    "enumerated" => UInt8,
    "boolean" => UInt8,
    "u-byte" => UInt8,
    "u-integer2" => UInt16,
    "u-integer4" => UInt32,
    "u-integer8" => UInt64,
    "byte" => Int8,
    "integer2" => Int16,
    "integer4" => Int32,
    "integer8" => Int64,
    "bitst(8)" => BitString{1},
    "bitst(16)" => BitString{2},
    "bitst(24)" => BitString{3},
    "bitst(32)" => BitString{4},
    "bitst(48)" => BitString{6},
    "bitst(64)" => BitString{8},
    "bitst(256)" => BitString{32},
    "v-integer2" => VInteger{Int16},
    "v-integer4" => VInteger{Int32},
    "v-integer8" => VInteger{Int64},
    "vu-byte" => VInteger{UInt8},
    "vu-integer2" => VInteger{UInt16},
    "vu-integer4" => VInteger{UInt32},
    "vu-integer8" => VInteger{UInt64}
)

function _get_field_name(row::CSV.Row)
    return Symbol(lowercase(replace(row.FIELD, ' ' => '_')))
end

function _get_description(row::CSV.Row)::AbstractString
    if ismissing(row.DESCRIPTION)
        return ""
    end
    return row.DESCRIPTION
end

function _get_scale_factor(row::CSV.Row)
    # some SFs are being read as Int64 and some as InlineStrings
    if !ismissing(row.SF)
        if row.SF isa Integer
            return row.SF
        else
            return ismissing(row.SF) ? nothing : tryparse(Int64, row.SF)
        end
    else
        nothing
    end
end

function _data_row(row::CSV.Row)
    if (row.OFFSET isa AbstractString) && strip(lowercase(row.OFFSET)) == "deleted"
        return false
    end
    return !(ismissing(row.TYPE) && ismissing(row.DIM1))
end

function _convert_dim(dim)
    if dim isa Integer
        return dim
    elseif dim isa AbstractString
        val_parse = tryparse(Int64, dim)
        if isnothing(val_parse)
            return Symbol(dim)
        else
            return val_parse
        end
    else
        error("can't convert dimension of type $(typeof(dim))")
    end
end

function _get_raw_format_dim(row)
    @assert hasproperty(row, :DIM1)
    dim1 = _convert_dim(row.DIM1)
    dim2 = hasproperty(row, :DIM2) ? _convert_dim(row.DIM2) : 1
    dim3 = hasproperty(row, :DIM3) ? _convert_dim(row.DIM3) : 1
    dim4 = hasproperty(row, :DIM4) ? _convert_dim(row.DIM4) : 1

    return (dim1, dim2, dim3, dim4)
end

function _get_type(row::CSV.Row)
    element_type = TYPE_NAMES[lowercase(row.TYPE)]
    field_dims = _get_raw_format_dim(row)

    if all(isa.(field_dims, Integer))
        # check size for fixed size fields.
        array_size = prod(field_dims)

        expected_type_size = row.var"TYPE SIZE" isa AbstractString ?
                             parse(Int64, row.var"TYPE SIZE") : Int64(row.var"TYPE SIZE")
        expected_field_size = row.var"FIELD SIZE" isa AbstractString ?
                              parse(Int64, row.var"FIELD SIZE") : Int64(row.var"FIELD SIZE")

        if native_sizeof(element_type) != expected_type_size
            error("Invalid type size. Returned $(native_sizeof(element_type)), expected $expected_type_size for row: $row")
        end

        if (native_sizeof(element_type) * array_size) != expected_field_size
            error("Invalid field size. Returned $(native_sizeof(element_type) * array_size) , expected $expected_field_size for row: $row")
        end

        if array_size == 1
            return element_type
        end
    end

    n_field_dimension = findlast(x -> x != 1, field_dims)

    return Array{element_type, n_field_dimension}
end

function _read_data_rows(file_name)
    csv_format = CSV.File(file_name)
    is_data_rows = _data_row.(csv_format)
    return csv_format[is_data_rows]
end

function description_dict(file_name)
    csv_format = _read_data_rows(file_name)
    return Dict(_get_field_name.(csv_format) .=> _get_description.(csv_format))
end

function scale_factor_dict(file_name)
    csv_format = _read_data_rows(file_name)
    return Dict(_get_field_name.(csv_format) .=> _get_scale_factor.(csv_format))
end

function raw_format_dim_dict(file_name)
    csv_format = _read_data_rows(file_name)
    return Dict(_get_field_name.(csv_format) .=> _get_raw_format_dim.(csv_format))
end

"""
    record_struct_expression(file_name, record_type)

Function to autogenerate `Struct` code based on a CSV file. 
Also autogenerates `get_description` and `get_scale_factor` method for `Struct`.
Use it together with `eval`.

# Example
```julia-repl
julia> eval(record_struct_expression(joinpath(@__DIR__, "TEST_FORmaT.csv"), DataRecord))
julia> TEST_FORMAT <: DataRecord
true
```
"""
function record_struct_expression(file_name, record_type)
    struct_name = basename(file_name)[1:(end - 4)]
    description_dict_name = Symbol(struct_name * "_DESCRIPTION")
    scale_dict_name = Symbol(struct_name * "_SCALE")
    dimension_dict_name = Symbol(struct_name * "_DIMENTION")
    struct_name = Symbol(uppercase(struct_name))

    csv_format = _read_data_rows(file_name)
    fields = [:($(_get_field_name(row))::$(_get_type(row))) for row in csv_format]

    auto_generated_code = quote
        struct $struct_name <: $record_type
            $(fields...)
        end

        const $description_dict_name = MetopDatasets.description_dict($file_name)
        MetopDatasets.get_description(T::Type{$struct_name}) = $description_dict_name

        const $scale_dict_name = MetopDatasets.scale_factor_dict($file_name)
        MetopDatasets.get_scale_factor(T::Type{$struct_name}) = $scale_dict_name

        const $dimension_dict_name = MetopDatasets.raw_format_dim_dict($file_name)
        MetopDatasets.get_raw_format_dim(T::Type{$struct_name}) = $dimension_dict_name

        function MetopDatasets.fixed_size(T::Type{$struct_name})
            return valtype($dimension_dict_name) <: NTuple{4, <:Integer}
        end
    end

    return auto_generated_code
end
