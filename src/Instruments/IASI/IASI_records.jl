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


IASI_SND_02_V11_format = joinpath(@__DIR__, "csv_formats/IASI_SND_02_V11.csv")

abstract type IASI_SND_02 <: DataRecord end
# create data structure, add description and scale factors
eval(record_struct_expression(IASI_SND_02_V11_format, IASI_SND_02))

function data_record_type(header::MainProductHeader, product_type::Val{:IASI_SND_02})::Type
    if header.format_major_version == 11
        return IASI_SND_02_V11
    else
        error("No format found for format major version :$(header.format_major_version)")
    end
end


function get_size_fields(::Type{<:IASI_SND_02})
    return Dict(
        :nerr     => :NERR,
        :co_nbr   => :CO_NBR,
        :hno3_nbr => :HNO3_NBR,
        :o3_nbr   => :O3_NBR,
        )
end



function native_read(io::IO, T::Type{<:IASI_SND_02})::T
    @warn "Method reads multiple Records due to flexible size" maxlog=1
    
    pos = position(io)

    # get sizes from giard
    seekstart(io)
    giard = read_first_record(io, GIADR_IASI_SND_02_V11);
    dims_from_giard = get_iasi_l2_flex_size(giard)

    seek(io, pos)
    return native_read_flexible(io, T, dims_from_giard)
end

