# MetopDatasets.jl
[![documentation stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://eumetsat.github.io/MetopDatasets.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://eumetsat.github.io/MetopDatasets.jl/dev/)
[![Build Status](https://github.com/eumetsat/MetopDatasets.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/eumetsat/MetopDatasets.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

MetopDatasets.jl is a package for reading products from the [METOP satellites](https://www.eumetsat.int/our-satellites/metop-series) using the native binary format specified for each product. The METOP satellites are part of the EUMETSAT-POLAR-SYSTEM (EPS) and have produced near real-time, global weather and climate observation since 2007. Learn more METOP and the data access on [EUMETSATs user-portal](https://user.eumetsat.int/dashboard).

MetopDatasets.jl exports the `MetopDataset` API which is an implementation of the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface and thus provides data access similar to e.g. [NCDatasets.jl](https://github.com/Alexander-Barth/NCDatasets.jl) and [GRIBDatasets.jl](https://github.com/JuliaGeo/GRIBDatasets.jl).

Only a subset of the METOP native formats are supported currently but we are continuously adding formats. The goal is to support all publicly available [native METOP products](https://data.eumetsat.int/extended?query=&filter=satellite__Metop&filter=availableFormats__Native). See [supported formats](https://eumetsat.github.io/MetopDatasets.jl/dev/#Supported-formats) for more information

It is also possible to use MetopDatasets.jl from Python. See [section in documentation](https://eumetsat.github.io/MetopDatasets.jl/dev/python) for more information.

## Copyright and License
This code is licensed under MIT license. See file LICENSE for details on the usage and distribution terms.
  
## Authors
* [Simon Kok Lupemba](mailto://simon.koklupemba@eumetsat.int) - *Maintainer* - [EUMETSAT](http://www.eumetsat.int)
* [Jonas Wilzewski](mailto://jonas.wilzewski@eumetsat.int) - *Contributor* - [EUMETSAT](http://www.eumetsat.int)

## Installation
MetopDatasets.jl can be installed via Pkg and the url to the GitHub repository.

```julia
import Pkg
Pkg.add(url="https://github.com/eumetsat/MetopDatasets.jl") 
```

## Examples
Open data set and list variables
```julia
using MetopDatasets
ds = MetopDataset("ASCA_SZO_1B_M03_20230329063300Z_20230329063556Z_N_C_20230329081417Z");
keys(ds)
```
REPL output:
```
("record_start_time", "record_stop_time", "degraded_inst_mdr", "degraded_proc_mdr", "utc_line_nodes", "abs_line_number", "sat_track_azi", "as_des_pass", "swath_indicator", "latitude", "longitude", "sigma0_trip", "kp", "inc_angle_trip", "azi_angle_trip", "num_val_trip", "f_kp", "f_usable", "f_land", 
"lcr", "flagfield")
```
Display variable information

```julia
ds["latitude"]
```
REPL output:
```
latitude (42 × 48)
  Datatype:    Float64 (Int32)
  Dimensions:  xtrack × atrack
  Attributes:
   description          = Latitude (-90 to 90 deg)
   scale_factor         = 1.0e-6
```
Load the complete variable
```julia
ds["latitude"][:,:]
```
REPL output:
```
42×48 Matrix{Float64}:
 -33.7308  -33.949   …  -43.7545  -43.9721
 -33.6969  -33.9152     -43.7252  -43.9429
 -33.6624  -33.8808     -43.695   -43.9127
 -33.6274  -33.8458     -43.6639  -43.8818
   ⋮                 ⋱                    
 -30.1606  -30.3748     -39.9343  -40.1446
 -30.0909  -30.3049  …  -39.8538  -40.0638
 -30.0206  -30.2344     -39.7726  -39.9823
```
See documentation page for more information.