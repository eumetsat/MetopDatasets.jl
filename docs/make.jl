# Copyright (c) 2024 EUMETSAT
# License: MIT

#### Code to build docs manually from terminal
# julia --project=docs
# import Pkg
# Pkg.resolve()
# include("docs/make.jl")'

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
        "Use with Python" => "python.md",
        "Examples" => [
            "ASCAT" => "ASCAT.md",
            "IASI" => "IASI.md"
        ],
        "Full API" => "full_api.md"
    ]
)

deploydocs(;
    repo = "github.com/eumetsat/MetopDatasets.jl",
    devbranch = "main"
)
