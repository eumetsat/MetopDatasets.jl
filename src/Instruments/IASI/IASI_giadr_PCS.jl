# Copyright (c) 2026 EUMETSAT
# License: MIT

# Add IASI Level PCS meta data record.
const GIADR_IASI_PCS_1C_V10_format = @path joinpath(
    @__DIR__, "csv_formats/GIADR_IASI_PCS_1C_V10.csv")

abstract type GIADR_IASI_PCS_1C <: GlobalInternalAuxiliary end

eval(record_struct_expression(GIADR_IASI_PCS_1C_V10_format, GIADR_IASI_PCS_1C))

get_instrument_subclass(::Type{<:GIADR_IASI_PCS_1C}) = 4

function get_flexible_dim_fields(::Type{<:GIADR_IASI_PCS_1C})
    return OrderedDict(
        :nbrscoresband1_part1 => :NBS1P1,
        :nbrscoresband1_part2 => :NBS1P2,
        :nbrscoresband1_part3 => :NBS1P3,
        :nbrscoresband2_part1 => :NBS2P1,
        :nbrscoresband2_part2 => :NBS2P2,
        :nbrscoresband2_part3 => :NBS2P3,
        :nbrscoresband3_part1 => :NBS3P1,
        :nbrscoresband3_part2 => :NBS3P2,
        :nbrscoresband3_part3 => :NBS3P3)
end

function get_flexible_dims_from_giard(giard::T) where {T <: GIADR_IASI_PCS_1C}
    flex_size_prod = OrderedDict{Symbol, Int64}()
    giard_size_fields = get_flexible_dim_fields(typeof(giard))

    for k in keys(giard_size_fields)
        value = getfield(giard, k)
        dim_name = giard_size_fields[k]
        flex_size_prod[dim_name] = value
    end

    return flex_size_prod
end
