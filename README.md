# Under development 
This package is still in the early development phase. Note that the package was previously named **MetopNative.jl** and was hosted on the [EUMETSAT GitLab](https://gitlab.eumetsat.int/eumetlab/cross-cutting-tools/MetopNative.jl) 

# MetopDatasets.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://eumetsat.github.io/MetopDatasets.jl/dev/)
[![Build Status](https://github.com/eumetsat/MetopDatasets.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/eumetsat/MetopDatasets.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

MetopDatasets.jl is a package for reading products from the [METOP satellites](https://www.eumetsat.int/our-satellites/metop-series) using the native binary format specified for each product. The METOP satellites are part of the EUMETSAT-POLAR-SYSTEM (EPS) and produce long series of near real-time weather and climate observation. Learn more and access the products on [EUMETSATs user-portal](https://user.eumetsat.int/dashboard).

MetopDatasets.jl has two APIs for reading native products. The first API is `MetopDataset` that implements the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface and thus provides data access similar to e.g. [NCDatasets.jl](https://github.com/Alexander-Barth/NCDatasets.jl) and [GRIBDatasets.jl](https://github.com/JuliaGeo/GRIBDatasets.jl). The second API is `MetopProduct` which reads an entire product into a Julia object with a data structure similar to the native file structure. 

Only a subset of the METOP native formats are supported currently but we are contiguously adding formats. The goal is to support all publicly available native METOP products.

## Copyright and License
This code is licensed under MIT license. See file LICENSE for details on the usage and distribution terms.
  
## Authors
* [Simon Kok Lupemba](mailto://simon.koklupemba@eumetsat.int) - *Maintainer* - [EUMETSAT](http://www.eumetsat.int)
* [Jonas Wilzewski](mailto://jonas.wilzewski@eumetsat.int) - *Contributor* - [EUMETSAT](http://www.eumetsat.int)

## Installation
MetopDatasets.jl can be installed via Pkg and the url to the github.com repo.

```julia
import Pkg
Pkg.add(url="https://github.com/eumetsat/MetopDatasets.jl") 
```

## Uninstall
```julia
import Pkg
Pkg.rm("MetopDatasets")
```


## Reference documents
The package is implemented based on
- [EPS Generic Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_gen_pfs_13e3f0feb7.pdf)
### Supported formats
- [ASCAT Level 1: Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/ASCAT_Level_1_Product_Format_V12_Annexe_50fe72d349.pdf)
- [ASCAT Level 2 Soil Moisture: Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_ten_0343_eps_ascatl2_pfs_f509981295.pdf)
- [IASI Level 1 Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_iasi_level_1_pfs_2105bc9ccf.pdf)

### Formats under development
- [IASI Level 2 Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_ten_980760_eps_iasi_l2_f9511c26d2.pdf)



## Examples

### Read data from a Metop Native binary file
To read a Metop Native binary file:

```julia
using MetopDatasets
ds = MetopDataset("ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat")
```
REPL output:
```
Dataset: 
Group: /

Dimensions
   num_band = 3
   xtrack = 82
   atrack = 3264

Variables
  record_start_time   (3264)
    Datatype:    Dates.DateTime (Float64)
    Dimensions:  atrack
    Attributes:
     description          = Record header start time
     units                = seconds since 2000-1-1 0:0:0

  record_stop_time   (3264)
    Datatype:    Dates.DateTime (Float64)
    Dimensions:  atrack
    Attributes:
     description          = Record header stop time
     units                = seconds since 2000-1-1 0:0:0

  degraded_inst_mdr   (3264)
    Datatype:    UInt8 (UInt8)
    Dimensions:  atrack
    Attributes:
     description          = Quality of MDR has been degraded from nominal due to an instrument degradation.

  degraded_proc_mdr   (3264)
    Datatype:    UInt8 (UInt8)
    Dimensions:  atrack
    Attributes:
     description          = Quality of MDR has been degraded from nominal due to a processing degradation. 

  utc_line_nodes   (3264)
    Datatype:    Dates.DateTime (Float64)
    Dimensions:  atrack
    Attributes:
     description          = UTC time of line of nodes
     units                = seconds since 2000-1-1 0:0:0

  abs_line_number   (3264)
    Datatype:    Int32 (Int32)
    Dimensions:  atrack
    Attributes:
     description          = Absolute (unique) counter for the line of nodes (from format version 12.0 onwards only)

  sat_track_azi   (3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  atrack
    Attributes:
     description          = Azimuth angle bearing (range: 0 to 360) of nadir track velocity
     scale_factor         = 0.010000000000000002

  as_des_pass   (3264)
    Datatype:    UInt8 (UInt8)
    Dimensions:  atrack
    Attributes:
     description          = Ascending/descending pass indicator

  swath_indicator   (82 × 3264)
    Datatype:    UInt8 (UInt8)
    Dimensions:  xtrack × atrack
    Attributes:
     description          = Swath (0=LEFT, 1=RIGHT)

  latitude   (82 × 3264)
    Datatype:    Float64 (Int32)
    Dimensions:  xtrack × atrack
    Attributes:
     description          = Latitude (-90 to 90 deg)
     scale_factor         = 1.0e-6

  longitude   (82 × 3264)
    Datatype:    Float64 (Int32)
    Dimensions:  xtrack × atrack
    Attributes:
     description          = Longitude (0 to 360 deg)
     scale_factor         = 1.0e-6

  sigma0_trip   (3 × 82 × 3264)
    Datatype:    Float64 (Int32)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Sigma0 triplet, re-sampled to swath grid, for 3 beams (fore, mid, aft) 
     scale_factor         = 1.0e-6

  kp   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Kp for re-sampled sigma0 tripplet. Values between 0 and 1
     scale_factor         = 0.0001

  inc_angle_trip   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Incidence angle for re-sampled sigma0 tripplet.
     scale_factor         = 0.010000000000000002

  azi_angle_trip   (3 × 82 × 3264)
    Datatype:    Float64 (Int16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Incidence angle for re-sampled sigma0 tripplet. Values range from -180 to +180, where minus is west and plus is east.
     scale_factor         = 0.010000000000000002

  num_val_trip   (3 × 82 × 3264)
    Datatype:    UInt32 (UInt32)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Number of full resolution sigma0 values contributing to the re-sampled sigma0 tripplet.

  f_kp   (3 × 82 × 3264)
    Datatype:    UInt8 (UInt8)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to the quality of the Kp estimate (0=NOMINAL, 1=NON-NOMINAL)

  f_usable   (3 × 82 × 3264)
    Datatype:    UInt8 (UInt8)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to the usability of the sigma0 tripplet (0=GOOD, 1=USABLE, 2=NOT USABLE)

  f_f   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to non-nominal amount of input raw data to calculate echo corrections (value between 0 and 1 shows the fraction of original samples 
affected)
     scale_factor         = 0.001

  f_v   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to non enough amount of input raw data to calculate echo corrections (value between 0 and 1 shows the fraction of original samples affected)
     scale_factor         = 0.001

  f_oa   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to lack of accuracy of orbit/atticute knowledge (value between 0 and 1 shows the fraction of original samples affected)
     scale_factor         = 0.001

  f_sa   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to solar array reflection contamination (value between 0 and 1 shows the fraction of original samples affected)
     scale_factor         = 0.001

  f_tel   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to non-nominal telemetry check results (value between 0 and 1 shows the fraction of original samples affected)
     scale_factor         = 0.001

  f_ref   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to non-nominal raw echo correction reference functions (value between 0 and 1 shows the fraction of original samples affected)      
     scale_factor         = 0.001

  f_land   (3 × 82 × 3264)
    Datatype:    Float64 (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to presence of land in the re-sampled sigma0 tripllet (value between 0 and 1 shows the fraction of original samples affected)       
     scale_factor         = 0.001

Global attributes
  product_name         = ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z
  parent_product_name_1 = ASCA_xxx_1A_M01_20190109125700Z_20190109143859Z_N_O_20190109134742Z
  parent_product_name_2 = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  parent_product_name_3 = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  parent_product_name_4 = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  instrument_id        = ASCA
  instrument_model     = 1
  product_type         = SZR
  processing_level     = 1B
  spacecraft_id        = M01
  sensing_start        = 2019-01-09T12:57:00
  sensing_end          = 2019-01-09T14:38:58
  sensing_start_theoretical = 2019-01-09T12:57:00
  sensing_end_theoretical = 2019-01-09T14:39:00
  processing_centre    = CGS1
  processor_major_version = 10
  processor_minor_version = 0
  format_major_version = 12
  format_minor_version = 0
  processing_time_start = 2019-01-09T13:48:16
  processing_time_end  = 2019-01-09T15:27:30
  processing_mode      = N
  disposition_mode     = O
  receiving_ground_station = SVL
  receive_time_start   = 2019-01-09T12:55:25
  receive_time_end     = 2019-01-09T15:24:35
  orbit_start          = 32745
  orbit_end            = 32746
  actual_product_size  = 26618899
  state_vector_time    = 2019-01-09T12:27:10
  semi_major_axis      = 7204713107
  eccentricity         = 1312
  inclination          = 98722
  perigee_argument     = 67970
  right_ascension      = 70895
  mean_anomaly         = 292186
  x_position           = -5122760992
  y_position           = 5061020490
  z_position           = 2084232
  x_velocity           = 1170132
  y_velocity           = 1168504
  z_velocity           = 7355678
  earth_sun_distance_ratio = 983395
  location_tolerance_radial = 0
  location_tolerance_crosstrack = 0
  location_tolerance_alongtrack = 0
  yaw_error            = 0
  roll_error           = 0
  pitch_error          = 0
  subsat_latitude_start = 71792
  subsat_longitude_start = -24448
  subsat_latitude_end  = 69881
  subsat_longitude_end = -52970
  leap_second          = 0
  leap_second_utc      =
  total_records        = 3283
  total_mphr           = 1
  total_sphr           = 1
  total_ipr            = 9
  total_geadr          = 1
  total_giadr          = 0
  total_veadr          = 5
  total_viadr          = 2
  total_mdr            = 3264
  count_degraded_inst_mdr = 0
  count_degraded_proc_mdr = 0
  count_degraded_inst_mdr_blocks = 0
  count_degraded_proc_mdr_blocks = 0
  duration_of_product  = 6118000
  milliseconds_of_data_present = 6056250
  milliseconds_of_data_missing = 0
  subsetted_product    = F
```

The variables can be loaded from MetopDataset by indexing the dataset. The variable then works as a lazy array loading the data on indexing:

```julia
ds["latitude"][2,4]
```
REPL output:
```
66.707944
```
It is also possible to load the complete array
```julia
ds["latitude"][:,:]
```
REPL output:
```
82×3264 Matrix{Float64}:
 66.862   66.7841  66.706   66.6276  66.5489  …  65.6304  65.5487  65.4667  65.3844  65.3019   
 66.9431  66.865   66.7866  66.7079  66.629      65.7077  65.6257  65.5434  65.4609  65.3782
  ⋮                                           ⋱            ⋮
 74.2237  74.1153  74.007   73.8986  73.7903  …  72.5493  72.4409  72.3325  72.2241  72.1157   
 74.2342  74.1259  74.0175  73.9092  73.8008     72.5597  72.4513  72.3429  72.2345  72.1261
```
Data from the main product header is accessed as attributes.
```julia
ds.attrib["instrument_id"]
```
REPL output:
```
"ASCA"
```
### Convert a Metop Native binary file to netCDF

A Metop Native binary file can be converted to netCDF using the [NCDatasets.jl](https://github.com/Alexander-Barth/NCDatasets.jl) package. This 
is possible because both MetopDatasets.jl and NCDatasets.jl implement the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface.

```julia
using MetopDatasets
using NCDatasets

input_file = "ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"
output_file = "ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nc"

ds_native = MetopDataset(input_file)
ds_nc = NCDataset(output_file, "c") 
NCDatasets.write(ds_nc, ds_native)

close(ds_native)
close(ds_nc)
```
It is also possible to use the safe `do` syntax that ensures the files are closed correctly even in the case of exceptions.

```julia
using MetopDatasets
using NCDatasets

input_file = "ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nat"
output_file = "ASCA_SZR_1B_M01_20190109125700Z_20190109143858Z_N_O_20190109134816Z.nc"

MetopDataset(input_file) do ds_native
  NCDataset(output_file, "c") do ds_nc
    NCDatasets.write(ds_nc, ds_native)
  end
end
```
