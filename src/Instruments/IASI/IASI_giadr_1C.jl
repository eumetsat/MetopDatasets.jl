# Copyright (c) 2024 EUMETSAT
# License: MIT

# Add IASI Level 1C meta data record.
const GIADR_IASI_xxx_1C_V11_format = @path joinpath(
    @__DIR__, "csv_formats/GIADR_IASI_xxx_1C_V11.csv")

abstract type GIADR_IASI_XXX_1C <: GlobalInternalAuxillary end

eval(record_struct_expression(GIADR_IASI_xxx_1C_V11_format, GIADR_IASI_XXX_1C))

get_instrument_subclass(::Type{<:GIADR_IASI_XXX_1C}) = 1

# functions to use the GIADR_IASI_XXX_1C

function max_giadr_channel(giadr::GIADR_IASI_XXX_1C)
    first_channel = giadr.idefscalesondnsfirst[1]
    n_bands = giadr.idefscalesondnbscale
    max_channel = giadr.idefscalesondnslast[n_bands] - first_channel + 1 # normally 8461
    return max_channel
end

function get_channel_scale_factor(giadr::GIADR_IASI_XXX_1C, channel_index::Integer)
    n_bands = giadr.idefscalesondnbscale
    off_set_channel = channel_index + giadr.idefscalesondnsfirst[1] - 1
    for i in 1:n_bands
        if giadr.idefscalesondnsfirst[i] <= off_set_channel <= giadr.idefscalesondnslast[i]
            return giadr.idefscalesondscalefactor[i]
        end
    end
    return error("Channel $channel_index scale factor not found")
end

function scale_iasi_spectrum!(
        aout, spec_raw, giadr::GIADR_IASI_XXX_1C, channel_range::OrdinalRange)
    # get the channel index.
    T = eltype(aout)
    max_channel = max_giadr_channel(giadr)
    for k in eachindex(channel_range)
        channel_index = channel_range[k]
        aout_spectrum = selectdim(aout, 1, k)
        if channel_index <= max_channel
            scale_factor = get_channel_scale_factor(giadr, channel_index)
            aout_spectrum .= selectdim(spec_raw, 1, k) .* T(10)^(-scale_factor)
        else
            aout_spectrum .= zero(T)
        end
    end
    return nothing
end

"""
    scale_iasi_spectrum(spec_raw, giadr::GIADR_IASI_XXX_1C; high_precision = false)
    scale_iasi_spectrum(spec_raw, giadr::GIADR_IASI_XXX_1C, channel_range::OrdinalRange; high_precision = false)

Scaling the IASI L1C spectrum using the giadr record information. The `channel_range` is needed if only a 
subset of the raw spectrum is passed to the function. 
Setting `high_precision=true` will convert to `Float64` instead of `Float32`. 
Note that the end part of the  `ds["gs1cspect"]` does not have any scale factors. Here the spectrum is just 
filled with `0.0`.

# Example
```julia-repl
julia> file_path = "test/testData/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"
julia> ds = MetopDataset(file_path, auto_convert = false);
julia> giadr = MetopDatasets.read_first_record(ds, MetopDatasets.GIADR_IASI_XXX_1C_V11)
julia> # Scale full spectrum.
julia> scaled_spectrum = MetopDatasets.scale_iasi_spectrum(ds["gs1cspect"], giadr)
julia> # Scale subset of spectrum.
julia> scaled_spectrum_subset = MetopDatasets.scale_iasi_spectrum(ds["gs1cspect"][10:20,:,:,:], giadr, 10:20)
```
"""
function scale_iasi_spectrum(
        spec_raw, giadr::GIADR_IASI_XXX_1C, channel_range::OrdinalRange; high_precision = false)
    # get the channel index.
    T = high_precision ? Float64 : Float32
    aout = similar(spec_raw, T)
    scale_iasi_spectrum!(aout, spec_raw, giadr, channel_range)

    return aout
end

function scale_iasi_spectrum(spec_raw, giadr::GIADR_IASI_XXX_1C; high_precision = false)

    ## Check that the spectrum is not cropped.
    channel_dim_length = size(spec_raw)[1]
    n_channels_total = _get_array_size(IASI_XXX_1C_V11, :gs1cspect)[1]
    n_channels_used = max_giadr_channel(giadr)

    if !((channel_dim_length == n_channels_total) ||
         (channel_dim_length == n_channels_used))
        return error("Expected $n_channels_total or $n_channels_used but got $channel_dim_length channels. channel_range input is needed to scale subsets.")
    end

    # forward method
    channel_range = 1:channel_dim_length
    return scale_iasi_spectrum(
        spec_raw, giadr, channel_range; high_precision = high_precision)
end
