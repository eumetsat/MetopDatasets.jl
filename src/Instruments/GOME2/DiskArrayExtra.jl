# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    GomeWavelengthDiskArray{T} <: AbstractMetopDiskArray{T, 2}

Lazy DiskArray for GOME-2 wavelength data for a single spectral band.
Shape: `(max_rec_length, n_records)`. Wavelengths are stored as Int32 with SF=6 (nm).
"""
struct GomeWavelengthDiskArray{T} <: AbstractMetopDiskArray{T, 2}
    file_pointer::IOStream
    field_name::Symbol
    record_type::Type{<:GOME_XXX_1B}
    spectral_info::GomeSpectralInfo
    band_index::Int
    dim_size::Tuple{Int64, Int64}
end

function GomeWavelengthDiskArray(
        file_pointer::IOStream,
        spectral_info::GomeSpectralInfo,
        record_type::Type{<:GOME_XXX_1B},
        band_index::Int,
        field_name::Symbol)
    n_records = length(spectral_info.record_offsets)
    max_rl = spectral_info.max_rec_lengths[band_index]
    dim_size = (Int64(max_rl), Int64(n_records))
    return GomeWavelengthDiskArray{Float64}(
        file_pointer, field_name, record_type, spectral_info, band_index, dim_size)
end

function DiskArrays.readblock!(
        disk_array::GomeWavelengthDiskArray{T},
        aout,
        i_wavelength::OrdinalRange,
        i_record::OrdinalRange) where {T}
    si = disk_array.spectral_info
    bi = disk_array.band_index

    for (k, rec_idx) in enumerate(i_record)
        rl = si.rec_lengths[bi, rec_idx]
        wl_offsets,
        _ = _compute_spectral_section_offsets(
            disk_array.file_pointer, si, rec_idx)

        # Read full wavelength array for this band
        seek(disk_array.file_pointer, wl_offsets[bi])
        raw = Vector{Int32}(undef, rl)
        read!(disk_array.file_pointer, raw)
        raw .= ntoh.(raw)

        for (j, wi) in enumerate(i_wavelength)
            if wi <= rl
                aout[j, k] = T(raw[wi]) * 1e-6  # SF=6
            else
                aout[j, k] = T(NaN)
            end
        end
    end
    return nothing
end

"""
    GomeRadianceDiskArray{T} <: AbstractMetopDiskArray{T, 3}

Lazy DiskArray for GOME-2 spectral band data (radiance, error, stokes, etc.) for a single band.
Shape: `(max_rec_length, max_num_recs, n_records)`.

The `component` field selects which value to extract from the compound band record:
- `:radiance` — decoded VInteger radiance
- `:radiance_error` — decoded VInteger error
- `:stokes_fraction` — Stokes fraction (main bands only, SF=6)
- `:uncorrected_radiance` — uncorrected radiance (PMD bands only)
- `:uncorrected_radiance_error` — uncorrected error (PMD bands only)
"""
struct GomeRadianceDiskArray{T} <: AbstractMetopDiskArray{T, 3}
    file_pointer::IOStream
    field_name::Symbol
    record_type::Type{<:GOME_XXX_1B}
    spectral_info::GomeSpectralInfo
    band_index::Int
    component::Symbol
    dim_size::Tuple{Int64, Int64, Int64}
end

function GomeRadianceDiskArray(
        file_pointer::IOStream,
        spectral_info::GomeSpectralInfo,
        record_type::Type{<:GOME_XXX_1B},
        band_index::Int,
        component::Symbol,
        field_name::Symbol)
    n_records = length(spectral_info.record_offsets)
    max_rl = spectral_info.max_rec_lengths[band_index]
    max_nr = spectral_info.max_num_recs[band_index]
    dim_size = (Int64(max_rl), Int64(max_nr), Int64(n_records))
    return GomeRadianceDiskArray{Float64}(
        file_pointer, field_name, record_type, spectral_info,
        band_index, component, dim_size)
end

function DiskArrays.readblock!(
        disk_array::GomeRadianceDiskArray{T},
        aout,
        i_wavelength::OrdinalRange,
        i_readout::OrdinalRange,
        i_record::OrdinalRange) where {T}
    si = disk_array.spectral_info
    bi = disk_array.band_index
    comp = disk_array.component
    is_pmd = bi >= 7  # bands 7-10 are PMD
    record_size = GOME2_BAND_RECORD_SIZES[bi]

    for (k, rec_idx) in enumerate(i_record)
        rl = si.rec_lengths[bi, rec_idx]
        nr = si.num_recs[bi, rec_idx]
        _,
        data_offsets = _compute_spectral_section_offsets(
            disk_array.file_pointer, si, rec_idx)

        # Read all band records for this record: nr × rl records
        total_pixels = rl * nr
        seek(disk_array.file_pointer, data_offsets[bi])
        raw_bytes = Vector{UInt8}(undef, total_pixels * record_size)
        readbytes!(disk_array.file_pointer, raw_bytes, total_pixels * record_size)

        for (jr, ri) in enumerate(i_readout)
            for (jw, wi) in enumerate(i_wavelength)
                if wi <= rl && ri <= nr
                    # Band data layout is: for each readout r, for each wavelength w
                    # pixel index = w + (r-1)*rl (column-major in file: wavelength varies fastest)
                    # Actually in defair the layout is (rec_length × num_recs), meaning
                    # wavelength varies fastest, readouts vary slowest
                    pixel_idx = (ri - 1) * rl + wi
                    byte_offset = (pixel_idx - 1) * record_size + 1  # 1-indexed

                    aout[jw, jr, k] = _extract_band_component(
                        T, raw_bytes, byte_offset, comp, is_pmd)
                else
                    aout[jw, jr, k] = T(NaN)
                end
            end
        end
    end
    return nothing
end

"""
    _extract_band_component(T, raw_bytes, offset, component, is_pmd)

Extract a single component value from a band record at the given byte offset.
Main band record (12 bytes): rad_sf(1) + rad(4) + err_sf(1) + err(2) + stokes(4)
PMD band record (16 bytes): rad_sf(1) + rad(4) + err_sf(1) + err(2) + uncorr_rad_sf(1) + uncorr_rad(4) + uncorr_err_sf(1) + uncorr_err(2)
"""
function _extract_band_component(
        ::Type{T}, raw::Vector{UInt8}, offset::Int, component::Symbol, is_pmd::Bool) where {T}
    if component == :radiance
        sf = reinterpret(Int8, raw[offset])[1]
        val = ntoh(reinterpret(Int32, @view(raw[(offset + 1):(offset + 4)]))[1])
        return T(val) * T(10)^(-Int(sf))
    elseif component == :radiance_error
        sf = reinterpret(Int8, raw[offset + 5])[1]
        val = ntoh(reinterpret(Int16, @view(raw[(offset + 6):(offset + 7)]))[1])
        return T(val) * T(10)^(-Int(sf))
    elseif component == :stokes_fraction && !is_pmd
        val = ntoh(reinterpret(Int32, @view(raw[(offset + 8):(offset + 11)]))[1])
        return T(val) * T(1e-6)  # SF=6
    elseif component == :uncorrected_radiance && is_pmd
        sf = reinterpret(Int8, raw[offset + 8])[1]
        val = ntoh(reinterpret(Int32, @view(raw[(offset + 9):(offset + 12)]))[1])
        return T(val) * T(10)^(-Int(sf))
    elseif component == :uncorrected_radiance_error && is_pmd
        sf = reinterpret(Int8, raw[offset + 13])[1]
        val = ntoh(reinterpret(Int16, @view(raw[(offset + 14):(offset + 15)]))[1])
        return T(val) * T(10)^(-Int(sf))
    else
        return T(NaN)
    end
end

"""
    GomeLayoutDiskArray <: AbstractMetopDiskArray{Int64, 1}

Simple DiskArray exposing per-record REC_LENGTH or NUM_RECS for a given band.
Shape: `(n_records,)`.
"""
struct GomeLayoutDiskArray <: AbstractMetopDiskArray{Int64, 1}
    field_name::Symbol
    data::Vector{Int64}
    dim_size::Tuple{Int64}
end

function GomeLayoutDiskArray(spectral_info::GomeSpectralInfo, band_index::Int,
        component::Symbol, field_name::Symbol)
    data = if component == :rec_length
        spectral_info.rec_lengths[band_index, :]
    else
        spectral_info.num_recs[band_index, :]
    end
    return GomeLayoutDiskArray(field_name, data, (Int64(length(data)),))
end

function DiskArrays.readblock!(
        disk_array::GomeLayoutDiskArray, aout, i::OrdinalRange)
    aout .= @view disk_array.data[i]
    return nothing
end
