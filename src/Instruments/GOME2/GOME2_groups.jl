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

"""
    GOME2L1BRoot

Sentinel data-record type parameterising the root `MetopDataset` of a GOME-2 L1B
product. The root dataset exposes no variables itself; the MDR subclasses present in
the file are accessed as groups (`"earthshine"`, `"calibration"`, `"sun"`, `"moon"`).
"""
struct GOME2L1BRoot <: DataRecord end

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
        record_type::Type{<:GOME_XXX_1B}, file_pointer::IO,
        main_product_header::MainProductHeader, auto_convert::Bool,
        high_precision::Bool, maskingvalue)
    @warn "GOME2 support is experimental" maxlog=1

    cache = Dict{Symbol, Any}(
        GOME2_GROUP_NAMES_CACHE_KEY => _gome2_group_names(file_pointer),
        GOME2_GROUPS_CACHE_KEY => Dict{String, MetopDataset}()
    )

    return MetopDataset{GOME2L1BRoot, FixedRecordLayout}(file_pointer,
        main_product_header,
        FixedRecordLayout[],
        0,
        auto_convert,
        high_precision,
        maskingvalue,
        cache)
end

# Scan all record headers and return the names of the MDR subclasses present in the
# file, in canonical order. Subclasses outside GOME2_SUBCLASS_GROUP_NAMES are ignored.
function _gome2_group_names(file_pointer::IO)::Vector{String}
    subclasses = Set{UInt8}()
    mdr_class = get_record_class(DataRecord)
    dummy_group = get_instrument_group(DummyRecord)

    seekstart(file_pointer)
    while !eof(file_pointer)
        record_offset = position(file_pointer)
        header = native_read(file_pointer, RecordHeader)
        if header.record_class == mdr_class && header.instrument_group != dummy_group
            push!(subclasses, header.instrument_subclass)
        end
        seek(file_pointer, record_offset + header.record_size)
    end

    return [name for (id, name) in GOME2_SUBCLASS_GROUP_NAMES if id in subclasses]
end

function CDM.groupnames(ds::MetopDataset{GOME2L1BRoot})
    return copy(ds.cache[GOME2_GROUP_NAMES_CACHE_KEY]::Vector{String})
end

function CDM.group(ds::MetopDataset{GOME2L1BRoot}, groupname::CDM.SymbolOrString)
    name = string(groupname)
    group_names = ds.cache[GOME2_GROUP_NAMES_CACHE_KEY]::Vector{String}
    if !(name in group_names)
        error("Product has no group \"$name\". Groups in product: " *
              join(group_names, ", "))
    end

    groups = ds.cache[GOME2_GROUPS_CACHE_KEY]::Dict{String, MetopDataset}
    return get!(() -> _gome2_group_dataset(ds, name), groups, name)
end

function _gome2_group_dataset(ds::MetopDataset{GOME2L1BRoot}, name::String)
    base_type = data_record_type(ds.main_product_header)
    record_type = _get_subclass_type(base_type, Symbol(name))

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
CDM.varnames(::MetopDataset{GOME2L1BRoot}) = String[]
CDM.dimnames(::MetopDataset{GOME2L1BRoot}) = String[]
MetopDatasets.get_dimensions(::Type{GOME2L1BRoot}) = OrderedDict{String, Int64}()

function CDM.variable(ds::MetopDataset{GOME2L1BRoot}, varname::CDM.SymbolOrString)
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
