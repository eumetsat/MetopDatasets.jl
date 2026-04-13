## GOME-2

The Global Ozone Monitoring Experiment-2 (GOME-2) is a nadir-scanning UV/visible spectrometer on the MetOp satellites. It measures Earth-backscattered radiance in the 240–790 nm wavelength range across six main spectral bands (1a, 1b, 2a, 2b, 3, 4) and four PMD bands (pp, ps, swpp, swps). The Level 1B product contains calibrated radiance spectra and associated geolocation data.

GOME-2 data is available from the [EUMETSAT Data Store](https://data.eumetsat.int/extended?query=&filter=instrument__GOME-2&filter=availableFormats__EPS%20Native).

Two format versions are supported:
- **V13** (NRT products): format\_major\_version 13, subclass version 6
- **V12** (FDR R3 reprocessed products): format\_major\_version 12, subclass version 5

Only MDR-1b-Earthshine records (instrument subclass 6) are read. Other record subclasses (e.g. subclass 7 for Sun reference spectra) have different binary layouts and are filtered out automatically.

### Opening a dataset

```julia
using MetopDatasets
import CommonDataModel as CDM

ds = MetopDataset("GOME_xxx_1B_M01_20260303213859Z_cropped_10.nat")
println(ds.main_product_header.format_major_version) # 13
println(ds.data_record_count) # number of scan lines
```

### Geolocation

Latitude and longitude are extracted from the interleaved CENTRE field. Each scan line has 32 ground pixels.

```julia
lat = ds["latitude"][:, 1]  # 32 latitudes for first scan
lon = ds["longitude"][:, 1]  # 32 longitudes for first scan

println("Latitude range: ", extrema(lat))
println("Longitude range: ", extrema(lon))
```

Geolocation fields (`centre`, `corner`, `scan_centre`, `scan_corner`, `sub_satellite_point`) include a `geo_component_order` attribute indicating the component ordering within the `geo_component` dimension.

### Spectral variables

When `auto_convert=true` (default), the dataset exposes spectral variables for each band. For example, band 1a:

```julia
wl = ds["wavelength_1a"][:, 1]   # wavelength grid (nm) for first scan
rad = ds["radiance_1a"][:, 1, 1] # radiance for first scan, first readout
```

Each band provides:
- `wavelength_{band}` — wavelength grid in nm
- `radiance_{band}` — calibrated or sun-normalized radiance
- `radiance_error_{band}` — radiance error estimate
- `stokes_fraction_{band}` — Stokes fraction (main bands 1a–4 only)
- `uncorrected_radiance_{band}` — uncorrected radiance (PMD bands only)
- `uncorrected_radiance_error_{band}` — uncorrected error (PMD bands only)
- `rec_length_{band}` — number of spectral elements per record
- `num_recs_{band}` — number of readout records per scan

### Output selection mode

The radiance units depend on the `OUTPUT_SELECTION` field in the product. The spectral variables include attributes that report the mode:

```julia
rad_var = CDM.variable(ds, "radiance_1a")
println(CDM.attrib(rad_var, "output_selection_mode"))  # "0" or "1"
println(CDM.attrib(rad_var, "units"))  # "photon s-1 cm-2 nm-1 sr-1" or "1"
```

- Mode 0 (`abs_rad`): calibrated radiance in photon s-1 cm-2 nm-1 sr-1
- Mode 1 (`norm_rad`): sun-normalized radiance (dimensionless)

### Fixed-header variables

The CSV-defined header fields are also accessible as variables:

```julia
sat_zenith = ds["sat_zenith"][:, :, :]  # (32, 3, n_records) — EFG triplets
solar_zenith = ds["solar_zenith"][:, :, :]
scanner_angle = ds["scanner_angle"][:, :]  # (65, n_records)
```

The EFG triplet dimensions represent points E (before), F (centre), and G (after) along the scan.

```julia
close(ds)
```
