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
    geo_data_sizes::Vector{Int64}      # n_records: summed GEO_EARTH_ACTUAL payload size
    rec_lengths::Matrix{Int64}         # 10 × n_records: spectral elements per band
    num_recs::Matrix{Int64}            # 10 × n_records: readout count per band
    wavelength_offsets::Matrix{Int64}  # 10 × n_records: absolute wavelength section offsets
    data_offsets::Matrix{Int64}        # 10 × n_records: absolute band data offsets
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
    band_record_sizes = gome2_band_record_sizes(record_type)

    geo_data_sizes = Vector{Int64}(undef, n_records)
    rec_lengths = Matrix{Int64}(undef, GOME2_N_BANDS, n_records)
    num_recs = Matrix{Int64}(undef, GOME2_N_BANDS, n_records)
    wavelength_offsets = Matrix{Int64}(undef, GOME2_N_BANDS, n_records)
    data_offsets = Matrix{Int64}(undef, GOME2_N_BANDS, n_records)

    for i in 1:n_records
        record_start = record_offsets[i]

        # Read GEO_REC_LENGTH: 10 × UInt16 at known fixed offset
        seek(file_pointer, record_start + geo_offset)
        geo_rec_lengths = Vector{UInt16}(undef, GOME2_N_BANDS)
        read!(file_pointer, geo_rec_lengths)
        geo_rec_lengths .= ntoh.(geo_rec_lengths)

        # Compute dynamic section start
        geo_data_size = sum(geo_rec_lengths) * GOME2_GEO_EARTH_ACTUAL_RECORD_SIZE
        geo_data_sizes[i] = geo_data_size
        dynamic_start = record_start + geo_offset + 20 + geo_data_size

        # Read REC_LENGTH[10] from dynamic section
        seek(file_pointer, dynamic_start + GOME2_DYNAMIC_REC_LENGTH_REL_OFFSET)
        rl = Vector{UInt16}(undef, GOME2_N_BANDS)
        read!(file_pointer, rl)
        rl_decoded = Int64.(ntoh.(rl))
        rec_lengths[:, i] .= rl_decoded

        # Read NUM_RECS[10] from dynamic section
        seek(file_pointer, dynamic_start + GOME2_DYNAMIC_NUM_RECS_REL_OFFSET)
        nr = Vector{UInt16}(undef, GOME2_N_BANDS)
        read!(file_pointer, nr)
        nr_decoded = Int64.(ntoh.(nr))
        num_recs[:, i] .= nr_decoded

        band_section_start = dynamic_start + GOME2_DYNAMIC_PREFIX_SIZE
        cursor = band_section_start
        for j in 1:GOME2_N_BANDS
            wavelength_offsets[j, i] = cursor
            cursor += rl_decoded[j] * 4 # Int32 wavelength
        end
        for j in 1:GOME2_N_BANDS
            data_offsets[j, i] = cursor
            cursor += nr_decoded[j] * rl_decoded[j] * band_record_sizes[j]
        end
    end

    max_rec_lengths = vec(maximum(rec_lengths, dims = 2))
    max_num_recs = vec(maximum(num_recs, dims = 2))

    return GomeSpectralInfo(
        record_offsets, geo_offset, geo_data_sizes,
        rec_lengths, num_recs, wavelength_offsets, data_offsets,
        max_rec_lengths, max_num_recs)
end

"""
    _compute_spectral_section_offsets(spectral_info, record_index)

Return cached absolute wavelength/data section offsets for one record.
"""
function _compute_spectral_section_offsets(
        spectral_info::GomeSpectralInfo, record_index::Int)
    wavelength_offsets = @view spectral_info.wavelength_offsets[:, record_index]
    data_offsets = @view spectral_info.data_offsets[:, record_index]
    return wavelength_offsets, data_offsets
end
