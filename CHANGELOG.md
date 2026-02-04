# Changelog

## Unreleased

## v0.2.2
- Use `OrderedDict` to ensure that dimensions always have the same order. Fixes: https://github.com/eumetsat/MetopDatasets.jl/issues/21
- Throw `KeyError` when an invalid variable name is given. Fixes: https://github.com/eumetsat/MetopDatasets.jl/issues/32
- Update links in documentation
- Add references to https://github.com/eumetsat/MetopPy in documentation.

## v0.2.1
- Upgrade to [CommonDataModel v0.4](https://github.com/JuliaGeo/CommonDataModel.jl/releases/tag/v0.4.0) 
- Add `get_scaled` helper function. The function helps get a field and apply the scale function for a single `Record`. Useful to handle auxiliary records.
- Add [AMSU-A Level 1 Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_amsu_a_l1_pfs_c89fa9d9ea.pdf)
- Add [HIRS Level 1 Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_ten_97230_eps_hirs4l1_pfs_0ddaefcb74.pdf)
- Add [MHS Level 1 Product Format Specification](https://user.eumetsat.int/s3/eup-strapi-media/pdf_ten_97229_eps_mhs_pfs_2069b45efc.pdf)

## v0.2.0
- Error message for invalid file types
- (**BREAKING**) Improved padding of flexible IASI L2 variables e.g. "o3_cp_air". The variable dimensions now matches the variable storing the location. See [issue 15](https://github.com/eumetsat/MetopDatasets.jl/issues/15) for more information.
- Internal changes to only use `FlexibleMetopDiskArray` for the IASI L2 flexible variables that varies in size between each record.
- (Fix) Remove "atrack" dimension from the IASI L2 GIARD variables e.g. "pressure_levels_temp".
- Add a lazy artifact with reduced test data which is used for CI testing.
- Precompilation using the lazy artifact with test data to reduce "time to first x".
- Use [RelocatableFolders.jl](https://github.com/JuliaPackaging/RelocatableFolders.jl) to make the installation of MetopDatasets.jl relocatable so it becomes more robust.

## v0.1
- (**BREAKING**) Initial release with support for IASI and ASCAT formats.