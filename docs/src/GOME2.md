## Experimental
The support for GOME-2 is experimental for the following reason 
- Only MDR-1b-Earthshine record are read. Measurements of the sun and the moon are skipped.
- The logic for the geolocation need to be documented and validated. The different bands have different numbers of measurements per scan line but the scan line always has 32 points with coordinates. 
- A random test exampled showed weird radiances for band 2a.

## GOME-2

The Global Ozone Monitoring Experiment-2 (GOME-2) is a nadir-scanning UV/visible spectrometer on the MetOp satellites. It measures Earth-backscattered radiance in the 240–790 nm wavelength range across six main spectral bands (1a, 1b, 2a, 2b, 3, 4) and four Polarisation Measurement Device (PMD) bands (pp, ps, swpp, swps). The Level 1B product contains calibrated radiance spectra and associated geolocation data.

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
println(ds.attrib["format_major_version"]) # 13
println(ds.dim["atrack"]) # number of scan lines
```

### Geolocation

Latitude and longitude are extracted from the interleaved CENTRE field. Each scan line has 32 ground pixels. The likely correspond to the second dimension of the band 1b, 2a, 2b, 3 and 4 radiation. The exact use of the geolocation still have to be documented. Note that band 1a and the PMD bands does not have 32 spectra per scan line so there geo location does not match the latitude and longitude variables one to one.

```julia
lat = ds["latitude"][:, 1]  # 32 latitudes for first scan
lon = ds["longitude"][:, 1]  # 32 longitudes for first scan

println("Latitude range: ", extrema(lat))
println("Longitude range: ", extrema(lon))
```

Multiple geolocation fields are available in the dataset `centre`, `corner`, `scan_centre`, `scan_corner` and `sub_satellite_point`.

### Spectral variables

The main observations in the product is the radiances and their wavelength. The first spectrum from band 1b can be loaded the following way:

```julia
wl = ds["wavelength_1b"][:, 1]   # wavelength grid (nm) for first scan
rad = ds["radiance_1b"][:, 1, 1] # radiance for first scan, first readout
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
rad_var = ds["radiance_1a"]
println(rad_var.attrib["output_selection_mode"])  # "0" or "1"
println(rad_var.attrib["units"])  # "photon s-1 cm-2 nm-1 sr-1" or "1"
```

- Mode 0 (`abs_rad`): calibrated radiance in photon s-1 cm-2 nm-1 sr-1
- Mode 1 (`norm_rad`): sun-normalized radiance (dimensionless)

### Auxiliary variables

The format also contains a range of auxiliary variables. Here are some examples.

```julia
sat_zenith = ds["sat_zenith"][:, :, :]  # (32, 3, n_records) — EFG triplets
solar_zenith = ds["solar_zenith"][:, :, :]
scanner_angle = ds["scanner_angle"][:, :]  # (65, n_records)
```

The EFG triplet dimensions represent points E (before), F (centre), and G (after) along the scan.

```julia
close(ds)
```
