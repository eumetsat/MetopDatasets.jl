```@meta
CurrentModule = MetopDatasets
```
# MetopDatasets.jl

MetopDatasets.jl is a package for reading products from the [METOP satellites](https://www.eumetsat.int/our-satellites/metop-series) using the native binary format specified for each product. The METOP satellites are part of the EUMETSAT-POLAR-SYSTEM (EPS) and have produced near real-time, global weather and climate observation since 2007. Learn more and access the products on [EUMETSATs user-portal](https://user.eumetsat.int/dashboard).

MetopDatasets.jl exports the `MetopDataset` API which is an implementation of the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface and thus provides data access similar to e.g. [NCDatasets.jl](https://github.com/Alexander-Barth/NCDatasets.jl) and [GRIBDatasets.jl](https://github.com/JuliaGeo/GRIBDatasets.jl).

Only a subset of the METOP native formats are supported currently, but we are continuously adding formats. The goal is to support all publicly available [native METOP products](https://data.eumetsat.int/extended?query=&filter=satellite__Metop&filter=availableFormats__Native). See [Supported formats](@ref) for more information.

It is also possible to use MetopDatasets.jl from Python. See [Use with Python](@ref) for more information.


## Quick start
This section gives a very short overview of the core functionalities. The [MetopDataset](@ref) page is recommend for more information and more specific examples are given in the Example section e.g. [ASCAT](@ref). The [NCDatasets documentation](https://alexander-barth.github.io/NCDatasets.jl/stable/) is also a great resource for information on how to use the datasets. 

### Installation
MetopDatasets.jl can be installed via Pkg.

```julia
import Pkg
Pkg.add("MetopDatasets")
```

### Read data from a Metop Native binary file
Read a Metop Native binary file and display meta data:

```julia
using MetopDatasets
ds = MetopDataset("ASCA_SZO_1B_M03_20230329063300Z_20230329063556Z_N_C_20230329081417Z")
```
REPL output:
```
Dataset: 
Group: /

Dimensions
   num_band = 3
   xtrack = 42
   atrack = 48

Variables
  record_start_time   (48)
    Datatype:    Dates.DateTime (Float64)
    Dimensions:  atrack
    Attributes:
     description          = Record header start time
     units                = seconds since 2000-1-1 0:0:0

  record_stop_time   (48)
    Datatype:    Dates.DateTime (Float64)
    Dimensions:  atrack
    Attributes:
     description          = Record header stop time
     units                = seconds since 2000-1-1 0:0:0

  degraded_inst_mdr   (48)
    Datatype:    Union{Missing, UInt8} (UInt8)
    Dimensions:  atrack
    Attributes:
     description          = Quality of MDR has been degraded from nominal due to an instrument degradation.
     missing_value        = UInt8[0xff]

  degraded_proc_mdr   (48)
    Datatype:    Union{Missing, UInt8} (UInt8)
    Dimensions:  atrack
    Attributes:
     description          = Quality of MDR has been degraded from nominal due to a processing degradation. 
     missing_value        = UInt8[0xff]

  utc_line_nodes   (48)
    Datatype:    Dates.DateTime (Float64)
    Dimensions:  atrack
    Attributes:
     description          = UTC time of line of nodes
     units                = seconds since 2000-1-1 0:0:0

  abs_line_number   (48)
    Datatype:    Union{Missing, Int32} (Int32)
    Dimensions:  atrack
    Attributes:
     description          = Absolute (unique) counter for the line of nodes (from format version 12.0 onwards only)
     missing_value        = Int32[-2147483648]

  sat_track_azi   (48)
    Datatype:    Union{Missing, Float64} (UInt16)
    Dimensions:  atrack
    Attributes:
     description          = Azimuth angle bearing (range: 0 to 360) of nadir track velocity
     missing_value        = UInt16[0xffff]
     scale_factor         = 0.010000000000000002

  as_des_pass   (48)
    Datatype:    Union{Missing, UInt8} (UInt8)
    Dimensions:  atrack
    Attributes:
     description          = Ascending/descending pass indicator (0=DESC, 1=ASC)
     missing_value        = UInt8[0xff]

  swath_indicator   (42 × 48)
    Datatype:    Union{Missing, UInt8} (UInt8)
    Dimensions:  xtrack × atrack
    Attributes:
     description          = Swath (0=LEFT, 1=RIGHT)
     missing_value        = UInt8[0xff]

  latitude   (42 × 48)
    Datatype:    Union{Missing, Float64} (Int32)
    Dimensions:  xtrack × atrack
    Attributes:
     description          = Latitude (-90 to 90 deg)
     missing_value        = Int32[-2147483648]
     scale_factor         = 1.0e-6

  longitude   (42 × 48)
    Datatype:    Union{Missing, Float64} (Int32)
    Dimensions:  xtrack × atrack
    Attributes:
     description          = Longitude (0 to 360 deg)
     missing_value        = Int32[-2147483648]
     scale_factor         = 1.0e-6

  sigma0_trip   (3 × 42 × 48)
    Datatype:    Union{Missing, Float64} (Int32)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Sigma0 triplet, re-sampled to swath grid, for 3 beams (fore, mid, aft) 
     missing_value        = Int32[-2147483648]
     scale_factor         = 1.0e-6

  kp   (3 × 42 × 48)
    Datatype:    Union{Missing, Float64} (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Kp for re-sampled sigma0 triplet. Values between 0 and 1
     missing_value        = UInt16[0xffff]
     scale_factor         = 0.0001

  inc_angle_trip   (3 × 42 × 48)
    Datatype:    Union{Missing, Float64} (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Incidence angle for re-sampled sigma0 triplet.
     missing_value        = UInt16[0xffff]
     scale_factor         = 0.010000000000000002

  azi_angle_trip   (3 × 42 × 48)
    Datatype:    Union{Missing, Float64} (Int16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Azimuth angle of the up-wind direction for a given measurement triplet (range: -180 to +180, where minus is west and plus is east with respect to North)
     missing_value        = Int16[-32768]
     scale_factor         = 0.010000000000000002

  num_val_trip   (3 × 42 × 48)
    Datatype:    Union{Missing, UInt32} (UInt32)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Number of full resolution sigma0 values contributing to the re-sampled sigma0 triplet.
     missing_value        = UInt32[0xffffffff]

  f_kp   (3 × 42 × 48)
    Datatype:    Union{Missing, UInt8} (UInt8)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to the quality of the Kp estimate (0=NOMINAL, 1=NON-NOMINAL)
     missing_value        = UInt8[0xff]

  f_usable   (3 × 42 × 48)
    Datatype:    Union{Missing, UInt8} (UInt8)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to the usability of the sigma0 triplet (0=GOOD, 1=USABLE, 2=NOT USABLE)        
     missing_value        = UInt8[0xff]

  f_land   (3 × 42 × 48)
    Datatype:    Union{Missing, Float64} (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag related to presence of land in the re-sampled sigma0 triplet (based on land mask; value between 0 and 1 shows the fraction of original samples affected)
     missing_value        = UInt16[0xffff]
     scale_factor         = 0.001

  lcr   (3 × 42 × 48)
    Datatype:    Union{Missing, Float64} (UInt16)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Land Contamination Ratio estimate (based on SRF)
     missing_value        = UInt16[0xffff]
     scale_factor         = 0.0001

  flagfield   (3 × 42 × 48)
    Datatype:    Union{Missing, UInt32} (UInt32)
    Dimensions:  num_band × xtrack × atrack
    Attributes:
     description          = Flag field containing quality information
     missing_value        = UInt32[0xffffffff]

Global attributes
  product_name         = ASCA_SZO_1B_M03_20230329063300Z_20230329063556Z_N_C_20230329081417Z
  parent_product_name_1 = ASCA_xxx_1A_M03_20230329063300Z_20230329063559Z_N_C_20230329081221Z
  parent_product_name_2 = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  parent_product_name_3 = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  parent_product_name_4 = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  instrument_id        = ASCA
  instrument_model     = 1
  product_type         = SZO
  processing_level     = 1B
  spacecraft_id        = M03
  sensing_start        = 2023-03-29T06:33:00
  sensing_end          = 2023-03-29T06:35:56
  sensing_start_theoretical = 2023-03-29T06:06:00
  sensing_end_theoretical = 2023-03-29T07:48:00
  processing_centre    = CGS2
  processor_major_version = 11
  processor_minor_version = 3
  format_major_version = 13
  format_minor_version = 1
  processing_time_start = 2023-03-29T08:14:17
  processing_time_end  = 2023-03-29T08:14:25
  processing_mode      = N
  disposition_mode     = C
  receiving_ground_station = SVL
  receive_time_start   = 2023-03-29T07:41:22
  receive_time_end     = 2023-03-29T07:42:22
  orbit_start          = 22777
  orbit_end            = 22778
  actual_product_size  = 171868
  state_vector_time    = 2023-03-29T05:33:10.999
  semi_major_axis      = 7204607302
  eccentricity         = 1053
  inclination          = 98685
  perigee_argument     = 57931
  right_ascension      = 149006
  mean_anomaly         = 302003
  x_position           = -3668934509
  y_position           = -6195727325
  z_position           = -20970818
  x_velocity           = -1426267
  y_velocity           = 827418
  z_velocity           = 7356929
  earth_sun_distance_ratio = 998227
  location_tolerance_radial = 0
  location_tolerance_crosstrack = 0
  location_tolerance_alongtrack = 0
  yaw_error            = 0
  roll_error           = 0
  pitch_error          = 0
  subsat_latitude_start = -32200
  subsat_longitude_start = 38892
  subsat_latitude_end  = -42446
  subsat_longitude_end = 35658
  leap_second          = 0
  leap_second_utc      =
  total_records        = 67
  total_mphr           = 1
  total_sphr           = 1
  total_ipr            = 9
  total_geadr          = 1
  total_giadr          = 0
  total_veadr          = 5
  total_viadr          = 2
  total_mdr            = 48
  count_degraded_inst_mdr = 0
  count_degraded_proc_mdr = 0
  count_degraded_inst_mdr_blocks = 0
  count_degraded_proc_mdr_blocks = 0
  duration_of_product  = 176250
  milliseconds_of_data_present = 176250
  milliseconds_of_data_missing = 0
  subsetted_product    = F
```
The variables can be loaded from MetopDataset by indexing the dataset. The variable then works as a lazy array loading the data on indexing:
```julia
ds["latitude"][2,4]
```
REPL output:
```
-34.351729
```
It is also possible to load the complete array
```julia
ds["latitude"][:,:]
```
REPL output:
```
42×48 Matrix{Union{Missing, Float64}}:
 -33.7308  -33.949   …  -43.7545  -43.9721
 -33.6969  -33.9152     -43.7252  -43.9429
 -33.6624  -33.8808     -43.695   -43.9127
 -33.6274  -33.8458     -43.6639  -43.8818
   ⋮                 ⋱                    
 -30.1606  -30.3748     -39.9343  -40.1446
 -30.0909  -30.3049  …  -39.8538  -40.0638
 -30.0206  -30.2344     -39.7726  -39.9823
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

## Supported formats
- ASCAT Level 1B
- ASCAT Level 2 Soil Moisture
- IASI Level 1C
- IASI Level 2 Combined Sounding

### Formats not yet supported
- AMSU-A Level 1B
- AVHRR Level 1B
- GOME-2 Level 1B
- HIRS Level 1B 
- MHS Level 1B 

### Reference documents 
- [EPS Generic Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_gen_pfs_13e3f0feb7.pdf)
- [ASCAT Level 1: Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/ASCAT_Level_1_Product_Format_V12_Annexe_50fe72d349.pdf)
- [ASCAT Level 2 Soil Moisture: Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_ten_0343_eps_ascatl2_pfs_f509981295.pdf)
- [IASI Level 1 Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_iasi_level_1_pfs_2105bc9ccf.pdf)
- [IASI Level 2 Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_ten_980760_eps_iasi_l2_f9511c26d2.pdf)

## Development status and versioning
The package was previously named **MetopNative.jl** and was hosted on the [EUMETSAT GitLab](https://gitlab.eumetsat.int/eumetlab/cross-cutting-tools/MetopNative.jl).

The aim is to follow the [semantic versioning](https://semver.org/) system. Note that the package is still 0.x.y to signal that breaking changes are to be expected. This is done to allow for more rapid development and because major dependencies like the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) are not at the version 1.0 milestone yet. It is therefore recommended to use [Pkg environments](https://pkgdocs.julialang.org/v1/compatibility/) for projects with MetopDatasets.jl to handle comparability and ensure reproducibility. Please note that many of the "breaking changes" will be small and only affect specific use cases. This could for example be the correction of a single variable name. All breaking changes are marked in the [changelog](https://github.com/eumetsat/MetopDatasets.jl/blob/main/CHANGELOG.md).