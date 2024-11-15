# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopDatasets
using Documenter

DocMeta.setdocmeta!(MetopDatasets, :DocTestSetup, :(using MetopDatasets); recursive = true)

makedocs(;
    modules = [MetopDatasets],
    authors = "lupemba <simon.koklupemba@eumetsat.int> and contributors",
    sitename = "MetopDatasets.jl",
    format = Documenter.HTML(;
        canonical = "https://eumetsat.github.io/MetopDatasets.jl",
        edit_link = "main",
        assets = String[]
    ),
    pages = [
        "Introduction" => "index.md",
        "Public API" => "public_api.md",
        "Internal API" => "internal_api.md"
    ]
)

deploydocs(;
    repo = "github.com/eumetsat/MetopDatasets.jl",
    devbranch = "main",
    push_preview = true
)
