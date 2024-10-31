# Copyright (c) 2024 EUMETSAT
# License: MIT

using Pkg
Pkg.develop(PackageSpec(path = pwd()))
Pkg.instantiate()
using Documenter: doctest
using MetopNative
doctest(MetopNative)
