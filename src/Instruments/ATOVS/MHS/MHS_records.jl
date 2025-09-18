
const MHS_XXX_1B_V10_format = @path joinpath(@__DIR__, "csv_formats/MHS_XXX_1B_V10.csv")

abstract type MHS_XXX_1B <: ATOVS_1B end
# create data structure, add description and scale factors
eval(record_struct_expression(MHS_XXX_1B_V10_format, MHS_XXX_1B))

function data_record_type(header::MainProductHeader, product_type::Val{:MHSx_xxx_1B})::Type
    if header.format_major_version == 10
        return MHS_XXX_1B_V10
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end

## GIADR_MHS_RADIANCE
const GIADR_MHS_RADIANCE_format = @path joinpath(
    @__DIR__, "csv_formats/GIADR_MHS_RADIANCE.csv")

eval(record_struct_expression(GIADR_MHS_RADIANCE_format, GlobalInternalAuxillary))
get_instrument_subclass(::Type{<:GIADR_MHS_RADIANCE}) = 2
