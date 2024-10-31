# Copyright (c) 2024 EUMETSAT
# License: MIT

using MetopNative
using Documenter

DocMeta.setdocmeta!(MetopNative, :DocTestSetup, :(using MetopNative); recursive = true)

makedocs(;
    modules = [MetopNative],
    authors = "lupemba <simon.koklupemba@eumetsat.int> and contributors",
    repo = "https://gitlab.eumetsat.int/eumetlab/cross-cutting-tools/MetopNative.jl/blob/{commit}{path}#{line}",
    sitename = "MetopNative.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://lupemba.gitlab.io/MetopNative.jl",
        edit_link = "main",
        assets = String[]),
    pages = [
        "Home" => "index.md"
    ])
