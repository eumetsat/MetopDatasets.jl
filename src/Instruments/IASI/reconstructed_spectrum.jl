# Copyright (c) 2026 EUMETSAT
# License: MIT
const IASI_RECONSTRUCT_NAME = :gs1cspect_reconstruct
const IASI_RECONSTRUCT_DESCRIPTION = "Level 1C spectra reconstructed from principal components"
const IASI_PCS_WAVENUMBER =  range(start=(2581 - 1)* 25.0, step = 25.0,length= 8461)
"""
    ReconstructedSpectrumDiskArray{T} <: AbstractMetopDiskArray{T, 4}


"""
struct ReconstructedSpectrumDiskArray{T} <: AbstractMetopDiskArray{T, 4}
    dim_size::NTuple{4, Int}
    m_reconstruct::BlockDiagonal{T}
    score_scale_factor::NTuple{3, T}
    missing_values::Tuple{Int32,Int16,Int8}
    pcscoresb1p1::MetopDiskArray{Int32,4}
    pcscoresb1p2::MetopDiskArray{Int16,4}
    pcscoresb1p3::MetopDiskArray{Int8,4}
    pcscoresb2p1::MetopDiskArray{Int32,4}
    pcscoresb2p2::MetopDiskArray{Int16,4}
    pcscoresb2p3::MetopDiskArray{Int8,4}
    pcscoresb3p1::MetopDiskArray{Int32,4}
    pcscoresb3p2::MetopDiskArray{Int16,4}
    pcscoresb3p3::MetopDiskArray{Int8,4}
end


function ReconstructedSpectrumDiskArray(ds::MetopDataset{<:IASI_PCS_1C}, 
    m_reconstruct::BlockDiagonal{T}, score_scale_factor::NTuple{3,T}) where {T}

    dim_size = (size(m_reconstruct,1), ds.dim["sounder_pixel"], ds.dim["xtrack"], ds.dim["atrack"])
    missing_values = (typemin(Int32),typemin(Int16),typemin(Int8))

    return ReconstructedSpectrumDiskArray{T}(
        dim_size,
        m_reconstruct,
        score_scale_factor,
        missing_values,
        ds["pcscoresb1p1"].var.data_array,
        ds["pcscoresb1p2"].var.data_array,
        ds["pcscoresb1p3"].var.data_array,
        ds["pcscoresb2p1"].var.data_array,
        ds["pcscoresb2p2"].var.data_array,
        ds["pcscoresb2p3"].var.data_array,
        ds["pcscoresb3p1"].var.data_array,
        ds["pcscoresb3p2"].var.data_array,
        ds["pcscoresb3p3"].var.data_array,
    )

end


function _get_iasi_eigen_files(ds::MetopDataset{IASI_PCS_1C_V10})

    eigen_artifact = LazyArtifacts.artifact"iasi_pcs_eigenvectors"
    f1 = joinpath(eigen_artifact, "IASI_EV1_xx_Mxx_20200131000000Z_xxxxxxxxxxxxxxZ_20200131000201Z_xxxx_xxxxxxxxxx")
    f2 = joinpath(eigen_artifact, "IASI_EV2_xx_Mxx_20200131000000Z_xxxxxxxxxxxxxxZ_20200131000201Z_xxxx_xxxxxxxxxx")
    f3 = joinpath(eigen_artifact, "IASI_EV3_xx_Mxx_20200131000000Z_xxxxxxxxxxxxxxZ_20200131000201Z_xxxx_xxxxxxxxxx")

    return [f1,f2,f3]
end


function DiskArrays.readblock!(reconstruct_disk_array::ReconstructedSpectrumDiskArray{T},
        aout,
        channel_range::OrdinalRange,
        j_range::OrdinalRange,
        k_range::OrdinalRange,
        l_range::OrdinalRange) where {T}

    # read the raw values
    aout .= zero(T)
    m_reconstruct = reconstruct_disk_array.m_reconstruct
    score_buffer = zeros(T, size(m_reconstruct, 2))
    raw_scores =(
        (
            reconstruct_disk_array.pcscoresb1p1[:, j_range, k_range, l_range],
            reconstruct_disk_array.pcscoresb1p2[:, j_range, k_range, l_range], 
            reconstruct_disk_array.pcscoresb1p3[:, j_range, k_range, l_range]  
        ),
        (
            reconstruct_disk_array.pcscoresb2p1[:, j_range, k_range, l_range],
            reconstruct_disk_array.pcscoresb2p2[:, j_range, k_range, l_range], 
            reconstruct_disk_array.pcscoresb2p3[:, j_range, k_range, l_range]  
        ),
        (
            reconstruct_disk_array.pcscoresb3p1[:, j_range, k_range, l_range],
            reconstruct_disk_array.pcscoresb3p2[:, j_range, k_range, l_range], 
            reconstruct_disk_array.pcscoresb3p3[:, j_range, k_range, l_range]  
        )
    )

    _reconstruct_iasi_pcs!(aout, 
        m_reconstruct, 
        raw_scores, 
        reconstruct_disk_array.score_scale_factor, 
        reconstruct_disk_array.missing_values,
        channel_range, 
        score_buffer)

    return aout
end


function _get_iasi_pcs_reconstruction(eigen_file)
    M_r = HDF5.h5open(eigen_file, "r") do ds_eigen
        HDF5.read_dataset(ds_eigen,"ReconstructionOperator")
    end
    return M_r
end

# custom function to avoid allocations in 
# mul!(C,A::view(BlockDiagonal),B)
function custom_block_view_mul!(C, M::BlockDiagonal, row_range::Union{UnitRange,StepRange}, B)
    current_global_row = 1
    current_global_cols = 1
    row_range_step = step(row_range)
    
    for block in M.blocks
        block_rows, block_cols = size(block)
        block_row_range = current_global_row:(current_global_row + block_rows - 1)
        block_cols_range = current_global_cols:(current_global_cols + block_cols - 1)
        
        # Check if the requested range overlaps with the current block
        overlap_range = intersect(row_range, block_row_range)
    
        
        if 0 < length(overlap_range)
            # 1. Map global row indices to the localized block row indices
            local_rows = overlap_range .- current_global_row .+ 1
            
            # 2. Map global row indices to your output matrix C row indices
            c_start =  div(first(overlap_range) - first(row_range), row_range_step) + 1
            c_range = range(start=c_start,length= length(overlap_range))
            
            # 3. Create allocation-free dense views of the components
            sub_block = view(block, local_rows, :)
            C_view    = view(C, c_range)
            B_view    = view(B, block_cols_range)

            # C_view += sub_block * B
            mul!(C_view, sub_block, B_view)
        end
        
        current_global_row += block_rows
        current_global_cols += block_cols
    end
    return C
end



function _fill_obs_scores!(score_buffer::Vector{T}, 
    raw_scores::NTuple{3,Tuple{Array{Int32, 4}, Array{Int16, 4}, Array{Int8, 4}}}, 
    score_scale_factor::NTuple{3,T}, 
    missing_values::Tuple{Int32, Int16, Int8}, 
    obs_index::NTuple{3,Int}) where {T <: Real}

    index_offset = 0 
    nan_val = T(NaN)
    for b in eachindex(raw_scores, score_scale_factor)
        score_var_band = raw_scores[b]
        scale_factor = score_scale_factor[b]
        # --- Manual Unrolling Example ---
        let 
            missing_val_i = missing_values[1]
            score_band_part = score_var_band[1]
            @views raw_score_slice = score_band_part[:, obs_index[1], obs_index[2], obs_index[3]]
            n_scores = length(raw_score_slice)
            @views score_slice = score_buffer[(1 + index_offset):(n_scores + index_offset)]
            has_missing = missing_val_i in raw_score_slice
            score_slice .= raw_score_slice .* ifelse(has_missing, nan_val, scale_factor)
            index_offset += n_scores 
        end
        
        let 
            missing_val_i = missing_values[2]
            score_band_part = score_var_band[2]
            @views raw_score_slice = score_band_part[:, obs_index[1], obs_index[2], obs_index[3]]
            n_scores = length(raw_score_slice)
            @views score_slice = score_buffer[(1 + index_offset):(n_scores + index_offset)]
            has_missing = missing_val_i in raw_score_slice
            score_slice .= raw_score_slice .* ifelse(has_missing, nan_val, scale_factor)
            index_offset += n_scores 
        end

        let 
            missing_val_i = missing_values[3]
            score_band_part = score_var_band[3]
            @views raw_score_slice = score_band_part[:, obs_index[1], obs_index[2], obs_index[3]]
            n_scores = length(raw_score_slice)
            @views score_slice = score_buffer[(1 + index_offset):(n_scores + index_offset)]
            has_missing = missing_val_i in raw_score_slice
            score_slice .= raw_score_slice .* ifelse(has_missing, nan_val, scale_factor)
            index_offset += n_scores 
        end
    end
    return score_buffer
end


function _reconstruct_iasi_pcs!(C_out::Array{T, 4}, 
    M_reconstruct::BlockDiagonal{T}, 
    raw_scores::NTuple{3,Tuple{Array{Int32, 4}, Array{Int16, 4}, Array{Int8, 4}}}, 
    score_scale_factor::NTuple{3,T}, 
    missing_values::Tuple{Int32, Int16, Int8},
    channel_range, 
    score_buffer = zeros(T,300)) where {T <: Real}

    # loop over each observation.
    for l in axes(C_out, 4)
        for k in axes(C_out, 3)
            for j in axes(C_out, 2)
                @views C_slice = C_out[:, j, k, l]
                _fill_obs_scores!(score_buffer, raw_scores, score_scale_factor, missing_values, (j,k,l))
                custom_block_view_mul!(C_slice, M_reconstruct, channel_range, score_buffer)
            end
        end
    end
    return C_out
end


function reconstruct_iasi_spectrum(ds::MetopDataset{R}, m_reconstruct::BlockDiagonal) where {R <: IASI_PCS_1C_V10}
    
    giadr = MetopDatasets.read_first_record(ds, GIADR_IASI_PCS_1C_V10)
    d_type = eltype(m_reconstruct)
    score_scale_factor = d_type.(Tuple(giadr.scorequantisationfactor./10^2))

    disk_array = ReconstructedSpectrumDiskArray(ds, m_reconstruct,  score_scale_factor)

    T = eltype(disk_array)
    N = ndims(disk_array)
    return MetopVariable{T, N, R, typeof(disk_array)}(ds, disk_array, IASI_RECONSTRUCT_NAME)
end

function reconstruct_iasi_spectrum(ds::MetopDataset{R}, eigen_files::AbstractVector{<:AbstractString}) where {R <: IASI_PCS_1C_V10}
    d_type = ds.high_precision ? Float64 : Float32
    m_reconstruct =  BlockDiagonal([d_type.(_get_iasi_pcs_reconstruction(f)) for f in eigen_files])
    return  reconstruct_iasi_spectrum(ds, m_reconstruct)
end


function reconstruct_iasi_spectrum(ds::MetopDataset{<:IASI_PCS_1C})
    reconstruct_iasi_spectrum(ds, _get_iasi_eigen_files(ds))
end

function CDM.varnames(ds::MetopDataset{R}) where {R <: IASI_PCS_1C}
    if ds.auto_convert
        public_names = (string(IASI_WAVENUMBER_NAME), default_varnames(ds)...)
        return public_names
    end

    return default_varnames(ds)
end

function CDM.variable(
        ds::MetopDataset{R}, varname::CDM.SymbolOrString)  where {R <: IASI_PCS_1C_V10}
    varname = Symbol(varname)

    if ds.auto_convert && varname == IASI_WAVENUMBER_NAME
        data_array = collect(IASI_PCS_WAVENUMBER)
        T = eltype(data_array)
        N = ndims(data_array)
        return MetopVariable{T, N, R, typeof(data_array)}(ds, data_array, varname)
    else
        return default_variable(ds, varname)
    end
end


function get_cf_attributes(ds::MetopDataset{R}, field::Symbol,
        auto_convert::Bool)::AbstractDict{Symbol, Any} where {R <: IASI_PCS_1C}
    if field == IASI_WAVENUMBER_NAME
        return Dict{Symbol, Any}(
            :units => "m-1"
        )
    elseif field == IASI_RECONSTRUCT_NAME
        d_type = ds.high_precision ? Float64 : Float32
        return Dict{Symbol, Any}(
            :units => "W/m2/sr/m-1",
            :missing_value  => d_type(NaN)
        )
    end

    return default_cf_attributes(R, field, auto_convert)
end

function CDM.attrib(
        v::MetopVariable{T, N, R}, name::CDM.SymbolOrString) where {T, N, R <: IASI_PCS_1C}
    
    if string(name) == "description"
        if v.field_name == IASI_WAVENUMBER_NAME
            return IASI_WAVENUMBER_DESCRIPTION
        elseif v.field_name == IASI_RECONSTRUCT_NAME
            return IASI_RECONSTRUCT_DESCRIPTION
        end
    end

    return default_attrib(v, name)
end

function CDM.dimnames(v::MetopVariable{T, N, R}) where {T, N, R <: IASI_PCS_1C}
    
    if v.field_name == IASI_WAVENUMBER_NAME
        return ["spectral"]
    end

    if v.field_name == IASI_RECONSTRUCT_NAME
        return ["spectral", "sounder_pixel", "xtrack", RECORD_DIM_NAME]
    end

    return default_dimnames(v)
end











