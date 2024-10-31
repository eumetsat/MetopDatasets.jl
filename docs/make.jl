# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Documenter

DocMeta.setdocmeta!(MetopDatasets, :DocTestSetup, :(using MetopDatasets); recursive = true)

makedocs(;
    modules = [MetopDatasets],
    authors = "lupemba <simon.koklupemba@eumetsat.int> and contributors",
    repo = "https://github.com/eumetsat/MetopDatasets.jl/blob/{commit}{path}#{line}",
    sitename = "MetopDatasets.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://eumetsat.github.io/MetopDatasets.jl",
        edit_link = "main",
        assets = String[]),
    pages = [
        "Home" => "index.md"
    ])
