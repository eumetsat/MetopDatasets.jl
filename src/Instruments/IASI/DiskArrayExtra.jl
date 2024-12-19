# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    IasiSpectrumDiskArray{T} <: AbstractMetopDiskArray{T, 4}

The `IasiSpectrumDiskArray` is a wrapper around a `MetopDiskArray` that enables the automatic
scaling of the the IASI L1C spectrum using the `GIADR_IASI_XXX_1C` record information.
"""
struct IasiSpectrumDiskArray{T} <: AbstractMetopDiskArray{T, 4}
    disk_array::MetopDiskArray
    giadr::GIADR_IASI_XXX_1C
end

# forward all getproperty (a.prop) to the disk_array except .disk_array and .giadr
function Base.getproperty(iasi_disk_array::IasiSpectrumDiskArray, sym::Symbol)
    if hasproperty(iasi_disk_array, sym)
        return getfield(iasi_disk_array, sym)
    end
    return getproperty(iasi_disk_array.disk_array, sym)
end

function IasiSpectrumDiskArray(file_pointer::IOStream,
        record_chunks::Vector{RecordChunk},
        field_name::Symbol; high_precision = false)
    @assert field_name == :gs1cspect
    giadr = read_first_record(file_pointer, GIADR_IASI_XXX_1C_V11)

    disk_array = MetopDiskArray(file_pointer,
        record_chunks,
        field_name; auto_convert = false)

    T = high_precision ? Float64 : Float32

    return IasiSpectrumDiskArray{T}(disk_array, giadr)
end

# Extend read function to also scale the spectrum using the giadr information.
function DiskArrays.readblock!(iasi_disk_array::IasiSpectrumDiskArray{T},
        aout,
        i::Vararg{OrdinalRange, 4}) where {T}

    # read the raw values
    disk_array_type = eltype(iasi_disk_array.disk_array)
    spec_raw = similar(aout, disk_array_type)
    DiskArrays.readblock!(iasi_disk_array.disk_array, spec_raw, i...)

    # compute the scaled spectrum
    channel_range = i[1]
    scale_iasi_spectrum!(aout, spec_raw, iasi_disk_array.giadr, channel_range)
    return nothing
end

"""
    IasiWaveNumberDiskArray <: AbstractMetopDiskArray{Float64, 2}

The `IasiWaveNumberDiskArray` is a disk array that computes the wavenumber of the IASI spectrum. The 
wavenumber is computed using `:idefnsfirst1b` and `:idefspectdwn1b` from each data record.
"""
struct IasiWaveNumberDiskArray <: AbstractMetopDiskArray{Float64, 2}
    record_type::Type{<:IASI_XXX_1C}
    field_name::Symbol
    number_of_first_sample::MetopDiskArray
    sample_width::MetopDiskArray
    size::Tuple{Int64, Int64}
end

const IASI_WAVENUMBER_NAME = :spectra_wavenumber
const IASI_WAVENUMBER_DESCRIPTION = "Wavenumber of IASI 1C spectra samples"

function IasiWaveNumberDiskArray(
        ds::MetopDataset{R}, field_name::Symbol) where {R <: IASI_XXX_1C}
    @assert field_name == IASI_WAVENUMBER_NAME

    number_of_first_sample = MetopDiskArray(
        ds.file_pointer, ds.data_record_chunks, :idefnsfirst1b)
    sample_width = MetopDiskArray(ds.file_pointer, ds.data_record_chunks, :idefspectdwn1b)

    spectrum_size = _get_array_size(R, :gs1cspect)[1]
    record_count = ds.data_record_count

    return IasiWaveNumberDiskArray(
        R, field_name, number_of_first_sample, sample_width, (spectrum_size, record_count))
end

Base.size(disk_array::IasiWaveNumberDiskArray) = disk_array.size

function DiskArrays.readblock!(disk_array::IasiWaveNumberDiskArray, aout,
        i_channel::OrdinalRange, i_record::OrdinalRange)
    number_of_first_sample = transpose(disk_array.number_of_first_sample[i_record])
    sample_width = transpose(disk_array.sample_width[i_record])

    aout .= sample_width .* (number_of_first_sample .+ i_channel .- 2)
    return nothing
end

function CDM.dimnames(disk_array::IasiWaveNumberDiskArray)
    spectrum_dim = get_field_dimensions(disk_array.record_type, :gs1cspect)[1]
    return [spectrum_dim, RECORD_DIM_NAME]
end
