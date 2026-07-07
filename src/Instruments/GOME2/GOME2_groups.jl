# Copyright (c) 2024 EUMETSAT
# License: MIT

# GOME-2 L1B products carry up to four MDR subclasses with different binary layouts
# (Earthshine, Calibration, Sun, Moon). Opening a GOME-2 L1B product therefore returns
# a root dataset without variables where every subclass present in the file is exposed
# as a group following the CommonDataModel group interface:
#
#   ds = MetopDataset(gome_file)
#   CDM.groupnames(ds)                    # e.g. ["earthshine", "calibration", "sun"]
#   ds_sun = CDM.group(ds, "sun")
#
# The groups share the file pointer of the root dataset, so closing any of them closes
# the whole dataset.

# MDR subclass IDs of the GOME-2 L1B product, in canonical group order.
const GOME2_SUBCLASS_GROUP_NAMES = OrderedDict{UInt8, String}(
    0x06 => "earthshine",
    0x07 => "calibration",
    0x08 => "sun",
    0x09 => "moon"
)

const GOME2_GROUP_NAMES_CACHE_KEY = :gome2_group_names
const GOME2_GROUPS_CACHE_KEY = :gome2_groups
const GOME2_GROUP_NAME_CACHE_KEY = :gome2_group_name
const GOME2_PARENT_CACHE_KEY = :gome2_parent_dataset

function MetopDatasets._construct_dataset(
        record_type::Type{<:GOME_XXX_1B_ROOT}, file_pointer::IO,
        main_product_header::MainProductHeader, auto_convert::Bool,
        high_precision::Bool, maskingvalue)
    @warn "GOME2 support is experimental" maxlog=1

    internal_pointer_records = _read_internal_pointer_records(file_pointer, main_product_header.total_ipr)

    cache = Dict{Symbol, Any}(
        GOME2_GROUP_NAMES_CACHE_KEY => _gome2_group_names(internal_pointer_records),
        GOME2_GROUPS_CACHE_KEY => Dict{String, MetopDataset}()
    )

    return MetopDataset{record_type, FixedRecordLayout}(file_pointer,
        main_product_header,
        FixedRecordLayout[],
        0,
        auto_convert,
        high_precision,
        maskingvalue,
        cache)
end

# Scan all internal pointer records and return the names of the MDR subclasses present in the
# file, in canonical order. Subclasses outside GOME2_SUBCLASS_GROUP_NAMES are ignored.
function _gome2_group_names(internal_pointer_records)::Vector{String}
    subclasses = Set{UInt8}()
    for pointer in internal_pointer_records
        is_data_record = pointer.record_class == get_record_class(DataRecord)
        is_dummy_record = pointer.instrument_group == get_instrument_group(DummyRecord)
        if is_data_record && !is_dummy_record
            push!(subclasses, pointer.instrument_subclass)
        end
    end

    return [name for (id, name) in GOME2_SUBCLASS_GROUP_NAMES if id in subclasses]
end

function CDM.groupnames(ds::MetopDataset{<:GOME_XXX_1B_ROOT})
    return copy(ds.cache[GOME2_GROUP_NAMES_CACHE_KEY]::Vector{String})
end

function CDM.group(ds::MetopDataset{<:GOME_XXX_1B_ROOT}, groupname::CDM.SymbolOrString)
    name = string(groupname)
    group_names = ds.cache[GOME2_GROUP_NAMES_CACHE_KEY]::Vector{String}
    if !(name in group_names)
        error("Product has no group \"$name\". Groups in product: " *
              join(group_names, ", "))
    end

    groups = ds.cache[GOME2_GROUPS_CACHE_KEY]::Dict{String, MetopDataset}

    if !haskey(groups, name)
        groups[name] = _gome2_group_dataset(ds, name)
    end

    return groups[name]
end

function _gome2_group_dataset(ds::MetopDataset{R}, name::String) where {R<:GOME_XXX_1B_ROOT}
    record_type = _get_subclass_type(R, Symbol(name))

    seek(ds.file_pointer, native_sizeof(MainProductHeader))
    _skip_sphr(ds.file_pointer, ds.main_product_header.total_sphr)

    record_layouts = read_record_layouts(ds.file_pointer, ds.main_product_header;
        record_type = record_type)
    data_record_layouts = filter(x -> x.record_type == record_type, record_layouts)
    data_record_count = data_record_layouts[end].record_range[end]

    cache = Dict{Symbol, Any}(
        GOME2_GROUP_NAME_CACHE_KEY => name,
        GOME2_PARENT_CACHE_KEY => ds
    )

    return MetopDataset{record_type, eltype(data_record_layouts)}(ds.file_pointer,
        ds.main_product_header,
        data_record_layouts,
        data_record_count,
        ds.auto_convert,
        ds.high_precision,
        ds.maskingvalue,
        cache)
end

# The root dataset only exposes global attributes and groups.
CDM.varnames(::MetopDataset{<:GOME_XXX_1B_ROOT}) = String[]
CDM.dimnames(::MetopDataset{<:GOME_XXX_1B_ROOT}) = String[]
MetopDatasets.get_dimensions(::Type{<:GOME_XXX_1B_ROOT}) = OrderedDict{String, Int64}()

function CDM.variable(ds::MetopDataset{<:GOME_XXX_1B_ROOT}, varname::CDM.SymbolOrString)
    group_names = ds.cache[GOME2_GROUP_NAMES_CACHE_KEY]::Vector{String}
    return error("GOME-2 L1B variables are accessed through the subclass groups, e.g. " *
                 "`CommonDataModel.group(ds, \"earthshine\")[\"$varname\"]`. " *
                 "Groups in product: " * join(group_names, ", "))
end

function CDM.name(ds::MetopDataset{<:GOME_XXX_1B})
    return get(ds.cache, GOME2_GROUP_NAME_CACHE_KEY, "/")::String
end

function CDM.parentdataset(ds::MetopDataset{<:GOME_XXX_1B})
    return get(ds.cache, GOME2_PARENT_CACHE_KEY, nothing)
end
