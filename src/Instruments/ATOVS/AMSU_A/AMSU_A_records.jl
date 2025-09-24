# Copyright (c) 2025 EUMETSAT
# License: MIT

const AMSA_XXX_1B_V10_format = @path joinpath(@__DIR__, "csv_formats/AMSA_XXX_1B_V10.csv")

abstract type AMSA_XXX_1B <: ATOVS_1B end
# create data structure, add description and scale factors
eval(record_struct_expression(AMSA_XXX_1B_V10_format, AMSA_XXX_1B))

function data_record_type(header::MainProductHeader, product_type::Val{:AMSA_xxx_1B})::Type
    if header.format_major_version == 10
        return AMSA_XXX_1B_V10
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end
