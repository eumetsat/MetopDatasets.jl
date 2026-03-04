# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    GomeSpectralInfo

Precomputed spectral layout metadata for GOME-2 MDR records. Computed once when
creating the spectral DiskArrays, then used for random access into variable-length
spectral data sections.
"""
struct GomeSpectralInfo
    record_offsets::Vector{Int64}      # byte offset of each MDR in file
    geo_rec_length_offset::Int64       # offset of GEO_REC_LENGTH within a record
    rec_lengths::Matrix{Int64}         # 10 × n_records: spectral elements per band
    num_recs::Matrix{Int64}            # 10 × n_records: readout count per band
    max_rec_lengths::Vector{Int64}     # 10: max rec_length across all records
    max_num_recs::Vector{Int64}        # 10: max num_recs across all records
end

"""
    compute_spectral_info(file_pointer, record_layouts, record_type)

Scan all MDR records to extract per-record spectral dimensions (REC_LENGTH, NUM_RECS)
and compute layout information needed for random access to spectral data.
"""
function compute_spectral_info(
        file_pointer::IO,
        record_layouts::Vector{<:RecordLayout},
        record_type::Type{<:GOME_XXX_1B})
    record_offsets = _layouts_to_offsets(record_layouts)
    n_records = length(record_offsets)
    geo_offset = gome2_geo_rec_length_offset(record_type)

    rec_lengths = Matrix{Int64}(undef, GOME2_N_BANDS, n_records)
    num_recs = Matrix{Int64}(undef, GOME2_N_BANDS, n_records)

    for i in 1:n_records
        record_start = record_offsets[i]

        # Read GEO_REC_LENGTH: 10 × UInt16 at known fixed offset
        seek(file_pointer, record_start + geo_offset)
        geo_rec_lengths = Vector{UInt16}(undef, GOME2_N_BANDS)
        read!(file_pointer, geo_rec_lengths)
        geo_rec_lengths .= ntoh.(geo_rec_lengths)

        # Compute dynamic section start
        geo_data_size = sum(geo_rec_lengths) * GOME2_GEO_EARTH_ACTUAL_RECORD_SIZE
        dynamic_start = record_start + geo_offset + 20 + geo_data_size

        # Read REC_LENGTH[10] from dynamic section
        seek(file_pointer, dynamic_start + GOME2_DYNAMIC_REC_LENGTH_REL_OFFSET)
        rl = Vector{UInt16}(undef, GOME2_N_BANDS)
        read!(file_pointer, rl)
        rec_lengths[:, i] .= ntoh.(rl)

        # Read NUM_RECS[10] from dynamic section
        seek(file_pointer, dynamic_start + GOME2_DYNAMIC_NUM_RECS_REL_OFFSET)
        nr = Vector{UInt16}(undef, GOME2_N_BANDS)
        read!(file_pointer, nr)
        num_recs[:, i] .= ntoh.(nr)
    end

    max_rec_lengths = vec(maximum(rec_lengths, dims = 2))
    max_num_recs = vec(maximum(num_recs, dims = 2))

    return GomeSpectralInfo(
        record_offsets, geo_offset,
        rec_lengths, num_recs,
        max_rec_lengths, max_num_recs)
end

"""
    _compute_spectral_section_offsets(file_pointer, spectral_info, record_index)

Compute the absolute file offset of the spectral section (after dynamic prefix)
for a given record. Returns per-band wavelength offsets and data offsets.
"""
function _compute_spectral_section_offsets(
        file_pointer::IO, spectral_info::GomeSpectralInfo, record_index::Int)
    record_start = spectral_info.record_offsets[record_index]
    geo_offset = spectral_info.geo_rec_length_offset
    rec_lengths = @view spectral_info.rec_lengths[:, record_index]
    num_recs = @view spectral_info.num_recs[:, record_index]

    # Read GEO_REC_LENGTH to compute dynamic section start
    seek(file_pointer, record_start + geo_offset)
    geo_rec_lengths = Vector{UInt16}(undef, GOME2_N_BANDS)
    read!(file_pointer, geo_rec_lengths)
    geo_rec_lengths .= ntoh.(geo_rec_lengths)

    geo_data_size = sum(geo_rec_lengths) * GOME2_GEO_EARTH_ACTUAL_RECORD_SIZE
    dynamic_start = record_start + geo_offset + 20 + geo_data_size

    # Band section starts after the dynamic prefix
    band_section_start = dynamic_start + GOME2_DYNAMIC_PREFIX_SIZE

    # Phase 1: wavelength arrays (all 10 bands, each rec_length × Int32)
    wavelength_offsets = Vector{Int64}(undef, GOME2_N_BANDS)
    cursor = band_section_start
    for j in 1:GOME2_N_BANDS
        wavelength_offsets[j] = cursor
        cursor += rec_lengths[j] * 4  # Int32 per wavelength element
    end

    # Phase 2: band data arrays
    data_offsets = Vector{Int64}(undef, GOME2_N_BANDS)
    for j in 1:GOME2_N_BANDS
        data_offsets[j] = cursor
        cursor += num_recs[j] * rec_lengths[j] * GOME2_BAND_RECORD_SIZES[j]
    end

    return wavelength_offsets, data_offsets
end
