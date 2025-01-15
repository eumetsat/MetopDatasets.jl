# Copyright (c) 2024 EUMETSAT
# License: MIT

abstract type Record end

abstract type BinaryRecord <: Record end

abstract type DataRecord <: BinaryRecord end

abstract type Header <: Record end

abstract type SecondaryProductHeader <: Header end

abstract type GlobalInternalAuxillary <: BinaryRecord end

abstract type RecordSubType end

abstract type RecordLayout end