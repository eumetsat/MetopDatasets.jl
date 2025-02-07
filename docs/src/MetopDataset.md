## MetopDataset

```@docs
MetopDataset
```


### Keys, attributes and dimensions.
These methods can help to explore the dataset without printing out everything. 

Use keys list the names of all variables without meta data
```julia
@show keys(ds)

# loop over all variables
for (varname,var) in ds
    # all variables
    @show (varname,size(var))
end
```

Access the attributes via the .attrib
```julia
@show ds.attrib

# attributes of a variable
example_var_name = keys(ds)[end]
example_var = ds[example_var_name]
@show example_var.attrib
```

Access the dimensions via the .dim and dimnames

```julia
@show ds.dim

# attributes of a variable
example_var_name = keys(ds)[end]
example_var = ds[example_var_name]
@show dimnames(example_var)
```

Note that `MetopDataset` is not implement any groups. Hence `isempty(ds.group)` is always true.
 
### Auto conversion and native types
The Metop native binary formats uses some custom data types. Theres are converted to standard netCDF compatible types by default. This conversion can be disable with the keyword argument `auto_convert=false`. Here is an example

```julia
ds = MetopDataset("IASI_xxx_1C_M01_20240925202059Z_20240925220258Z_N_O_20240925211316Z.nat")

function show_example(ds, var_name)
    val = ds[var_name][1]
    @show var_name
    @show typeof(val)
    @show val
    println()
end


MetopDataset(iasi_file, auto_convert=false) do ds
    println("With auto_convert=false")
    println()
    show_example(ds,"record_start_time");
    show_example(ds,"gepsiasimode");
    show_example(ds,"gepslociasiavhrr_iasi");
end
```

Output
```
With auto_convert=false

var_name = "record_start_time"
typeof(val) = MetopDatasets.ShortCdsTime
val = MetopDatasets.ShortCdsTime(0x234a, 0x045dd976)

var_name = "gepsiasimode"
typeof(val) = MetopDatasets.BitString{4}
val = 00000000000000000000000010100001


var_name = "gepslociasiavhrr_iasi"
typeof(val) = MetopDatasets.VInteger{Int32}
val = MetopDatasets.VInteger{Int32}(6, -1965000000)
```


If we run the same example with auto convert on.

```julia
MetopDataset(iasi_file, auto_convert=true) do ds
    println("With auto_convert=true")
    println()
    show_example(ds,"record_start_time");
    show_example(ds,"gepsiasimode");
    show_example(ds,"gepslociasiavhrr_iasi");
end
```

Output
```
With auto_convert=true

var_name = "record_start_time"
typeof(val) = Dates.DateTime
val = Dates.DateTime("2024-09-25T20:20:59.382")

var_name = "gepsiasimode"
typeof(val) = UInt32
val = 0x000000a1

var_name = "gepslociasiavhrr_iasi"
typeof(val) = Float64
val = -1965.0
```

Note that the `auto_convert` argument also controls if the IASI L1 spectrum "gs1cspect" is automatically scaled. Multiple scale factors are needed to scale the spectrum and therefore the scaling of the spectrum is handled different from other variables. The spectrum is automatically scaled to `Float32` to save memory. Use the `high_precision=true` argument to change this to `Float64`.

### Missing values
Note that the datasets can contain missing values. This is especially true for product formats with flexible dimensions like the IASI L2 products. Here is an example.

```julia
using MetopDatasets
ds = MetopDataset("IASI_SND_02_M01_20241215173256Z_20241215173552Z_N_C_20241215182326Z");

ds["atmospheric_temperature"][:,:,6]
```
Output
```
101×120 Matrix{Union{Missing, Float64}}:    
 190.85      189.27      …  missing  missing
 195.62      193.93         missing  missing     
 204.47      202.59         missing  missing     
 212.82      210.87         missing  missing     
   ⋮                     ⋱
    missing     missing     missing  missing     
    missing     missing     missing  missing     
    missing     missing  …  missing  missing  
```
Here the output variable is `Union{Missing, Float64}` which can be difficult to work with. Sometimes it can be and advatange to replace the `missing` values with `NaN` values. This can be done on the variable level.

```julia
var_no_missing = cfvariable(ds, "atmospheric_temperature", maskingvalue = NaN)
var_no_missing[:,:,6]
```
Output
```
101×120 Matrix{Float64}:
 190.85  189.27  189.0   …  NaN  NaN  NaN  NaN   
 195.62  193.93  193.69     NaN  NaN  NaN  NaN   
 204.47  202.59  202.49     NaN  NaN  NaN  NaN   
 212.82  210.87  210.99     NaN  NaN  NaN  NaN   
   ⋮                     ⋱
 NaN     NaN     NaN        NaN  NaN  NaN  NaN   
 NaN     NaN     NaN        NaN  NaN  NaN  NaN   
 NaN     NaN     NaN     …  NaN  NaN  NaN  NaN
```

Note that this is not recommend for integer fields since it results in an automatic conversion to float. This is especially and issue in the cases where the integer value is a representation of an underlying bit string.

```julia
var_temp_error = cfvariable(ds, "temperature_error", maskingvalue = NaN)

val_as_scalar = var_temp_error[1,1,1]
val_as_array = var_temp_error[1:1,1,1]

@show val_as_scalar, bitstring(val_as_scalar);
@show val_as_array, bitstring.(val_as_array); #wrong bitstring due to conversion
```
Output
```
(val_as_scalar, bitstring(val_as_scalar)) = (0x4277d0a4, "01000010011101111101000010100100")
(val_as_array, bitstring.(val_as_array)) = ([1.115148452e9], ["0100000111010000100111011111010000101001000000000000000000000000"])
```

It is also possible to set the `maskingvalue` for an entire dataset. This is convenient but can lead to issues regarding integers as illustrated above. Here is an example:


```julia
ds_no_missing = MetopDataset("IASI_SND_02_M01_20241215173256Z_20241215173552Z_N_C_20241215182326Z", maskingvalue = NaN);
ds_no_missing["atmospheric_temperature"][:,:,6]
```
Output
```
101×120 Matrix{Float64}:
 190.85  189.27  189.0   …  NaN  NaN  NaN  NaN   
 195.62  193.93  193.69     NaN  NaN  NaN  NaN   
 204.47  202.59  202.49     NaN  NaN  NaN  NaN   
 212.82  210.87  210.99     NaN  NaN  NaN  NaN   
   ⋮                     ⋱
 NaN     NaN     NaN        NaN  NaN  NaN  NaN   
 NaN     NaN     NaN        NaN  NaN  NaN  NaN   
 NaN     NaN     NaN     …  NaN  NaN  NaN  NaN
```
