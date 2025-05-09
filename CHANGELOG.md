# Changelog

## Unreleased
- Error message for invalid file types
- (**BREAKING**) Improved padding of flexible IASI L2 variables e.g. "o3_cp_air". The variable dimensions now matches the variable storing the location. See [issue 15](https://github.com/eumetsat/MetopDatasets.jl/issues/15) for more information.
- Internal changes to only use `FlexibleMetopDiskArray` for the IASI L2 flexible variables that varies in size between each record.
- (Fix) Remove "atrack" dimension from the IASI L2 GIARD variables e.g. "pressure_levels_temp".
- Add a lazy artifact with reduced test data which is used for CI testing.
- Precompilation using the lazy artifact with test data to reduce "time to first x".

## v0.1
- (**BREAKING**) Initial release with support for IASI and ASCAT formats.