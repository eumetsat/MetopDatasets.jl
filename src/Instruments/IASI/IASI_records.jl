# Copyright (c) 2024 EUMETSAT
# License: MIT

IASI_xxx_1C_V11_format = joinpath(@__DIR__, "csv_formats/IASI_xxx_1C_V11.csv")

abstract type IASI_XXX_1C <: DataRecord end
# create data structure, add description and scale factors
eval(record_struct_expression(IASI_xxx_1C_V11_format, IASI_XXX_1C))

function data_record_type(header::MainProductHeader, product_type::Val{:IASI_xxx_1C})::Type
    if header.format_major_version == 11
        return IASI_XXX_1C_V11
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end
