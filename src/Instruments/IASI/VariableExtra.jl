# Copyright (c) 2024 EUMETSAT
# License: MIT

function CDM.varnames(ds::MetopDataset{R}) where {R <: IASI_XXX_1C}
    if ds.auto_convert
        public_names = (string(IASI_WAVE_NUMBER_NAME), default_varnames(ds)...)
        return public_names
    end

    return default_varnames(ds)
end

# Overload to enable special scaling for IASI spectrum.
function CDM.variable(
        ds::MetopDataset{R}, varname::CDM.SymbolOrString) where {R <: IASI_XXX_1C}
    if ds.auto_convert && Symbol(varname) == :gs1cspect
        sepctrum_disk_array = IasiSpectrumDiskArray(ds.file_pointer, ds.data_record_chunks,
            Symbol(varname); high_precision = ds.high_precision)
        T = eltype(sepctrum_disk_array)
        N = ndims(sepctrum_disk_array)
        return MetopVariable{T, N, R}(ds, sepctrum_disk_array)

    elseif ds.auto_convert && Symbol(varname) == IASI_WAVE_NUMBER_NAME
        wave_number_disk_array = IasiWaveNumberDiskArray(ds, Symbol(varname))
        T = eltype(wave_number_disk_array)
        N = ndims(wave_number_disk_array)

        return MetopVariable{T, N, R}(ds, wave_number_disk_array)
    end

    return default_variable(ds, varname)
end

# Overload to add :gircimage scale_factor from giadr. Not given in the format specs like the rest.
function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::Dict{Symbol, Any} where {R <: IASI_XXX_1C}
    if field == IASI_WAVE_NUMBER_NAME
        return Dict{Symbol, Any}(
            :units => "m-1"
        )
    end

    cf_attributes = default_cf_attributes(R, field, auto_convert)

    if field == :gircimage
        giadr = read_first_record(ds, GIADR_IASI_XXX_1C_V11)
        scale_factor = giadr.idefscaleiisscalefactor
        cf_attributes[:scale_factor] = 10.0^(-scale_factor)
    end

    return cf_attributes
end

function CDM.attrib(
        v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {T, N, R <: IASI_XXX_1C}
    if (v.disk_array.field_name == IASI_WAVE_NUMBER_NAME) && (string(name) == "description")
        return IASI_WAVE_NUMBER_DESCRIPTION
    end

    return default_attrib(v, name)
end
