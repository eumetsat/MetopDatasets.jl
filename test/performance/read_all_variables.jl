# Copyright (c) 2025 EUMETSAT
# License: MIT

using MetopDatasets, BenchmarkTools

@assert isdir("test/testData")

# Full orbit, 24 MB
ASCAT_SZR = "test/testData/ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"

# 3 min IASI L2, 24 MB
IASI_L2 = "test/testData/IASI_SND_02_M01_20241215173256Z_20241215173552Z_N_C_20241215182326Z"

# 3 min IASI L1, 59 MB
IASI_L1 = "test/testData/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"

function read_all(file_path)
    all_vars = MetopDataset(file_path) do ds
        return [Array(ds[k]) for k in keys(ds)]
    end
    return all_vars
end

# first calls 
# 13.727169 seconds (49.09 M allocations: 1.931 GiB, 4.18% gc time, 87.52% compilation time)
@time read_all(ASCAT_SZR);

# 10.402657 seconds (33.70 M allocations: 1.342 GiB, 4.22% gc time, 78.76% compilation time)
@time read_all(IASI_L2);

# 25.318861 seconds (57.84 M allocations: 3.162 GiB, 3.00% gc time, 95.64% compilation time)
@time read_all(IASI_L1);

BenchmarkTools.DEFAULT_PARAMETERS.seconds = 20.0

# Range (min … max):  1.238 s …   1.426 s  ┊ GC (min … max): 2.50% … 3.18%
# Range (min … max):  1.477 s …   1.685 s  ┊ GC (min … max):  4.19% … 13.03%
@benchmark read_all(ASCAT_SZR)

# Range (min … max):  2.120 s …    2.433 s  ┊ GC (min … max): 1.46% … 14.77%
@benchmark read_all(IASI_L2)

# Range (min … max):  833.567 ms …    1.480 s  ┊ GC (min … max):  0.86% … 17.55%
@benchmark read_all(IASI_L1)

@profview read_all(ASCAT_SZR)

@profview read_all(IASI_L1)

@profview read_all(IASI_L2)
