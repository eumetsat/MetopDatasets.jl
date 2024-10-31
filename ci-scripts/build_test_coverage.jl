# Copyright (c) 2024 EUMETSAT
# License: MIT

using Pkg

Pkg.test(coverage = true)

Pkg.add(PackageSpec(name = "CoverageTools"))
using CoverageTools
c, t = get_summary(process_folder())
println("Test coverage ", round(100 * c / t, digits = 2))
