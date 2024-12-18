# Copyright (c) 2024 EUMETSAT
# License: MIT

"""
    brightness_temperature(I::T, wave_number::Real, default=T(NaN)) where T <: Real

Converting the IASI L1C spectrum from radiances to brightness temperature.
Note that the wave number must in meters^-1

# Example
```julia-repl
julia> file_path = "test/testData/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"
julia> ds = MetopDataset(file_path);
julia> spectrum = ds["gs1cspect"][:,1,1,1]
julia> wave_number = ds["spectra_wave_number"][:, 1]
julia> # convert from radiances to brightness temperature
julia> T_B = brightness_temperature.(spectrum, wave_number)
```
"""
function brightness_temperature(I::T, wave_number::Real, default = T(NaN)) where {T <: Real}
    # IASI Level 2: Product Generation Specification
    # Equation 26
    c1 = 1.1910427e-16
    c2 = 1.4387752e-2

    if I > 0
        T_brightness = c2 * wave_number / log(1 + c1 * wave_number^3 / I)
        return T_brightness
    else
        return default
    end
end
