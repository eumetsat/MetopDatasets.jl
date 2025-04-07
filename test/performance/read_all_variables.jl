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
#  17.111785 seconds (32.62 M allocations: 1.784 GiB, 2.08% gc time, 93.07% compilation time)
@time read_all(ASCAT_SZR);

# 14.128396 seconds (26.23 M allocations: 1.485 GiB, 3.81% gc time, 83.40% compilation time)
@time read_all(IASI_L2);

# 18.414896 seconds (35.12 M allocations: 2.186 GiB, 2.76% gc time, 91.33% compilation time)
@time read_all(IASI_L1);

BenchmarkTools.DEFAULT_PARAMETERS.seconds = 20.0

# Range (min … max):  862.515 ms …    1.170 s  ┊ GC (min … max):  1.72% … 19.98%
# Time  (mean ± σ):   997.275 ms ± 111.882 ms  ┊ GC (mean ± σ):  10.25% ±  9.42%
@benchmark read_all(ASCAT_SZR)

# Range (min … max):  2.140 s …    2.804 s  ┊ GC (min … max): 1.06% … 9.41%
# Time  (median):     2.372 s               ┊ GC (median):    9.79%
# Time  (mean ± σ):   2.421 s ± 204.805 ms  ┊ GC (mean ± σ):  7.29% ± 4.06%
@benchmark read_all(IASI_L2)

# Range (min … max):  1.061 s …    1.866 s  ┊ GC (min … max):  1.75% … 19.29%
# Time  (median):     1.310 s               ┊ GC (median):    17.09%
# Time  (mean ± σ):   1.346 s ± 217.894 ms  ┊ GC (mean ± σ):  12.50% ±  7.92%
@benchmark read_all(IASI_L1)

@profview read_all(ASCAT_SZR)

@profview read_all(IASI_L1)

@profview read_all(IASI_L2)
