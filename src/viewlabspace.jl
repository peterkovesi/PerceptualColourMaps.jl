#=----------------------------------------------------------------------------

Copyright (c) 2015 Peter Kovesi
pk@peterkovesi.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

The Software is provided "as is", without warranty of any kind.

----------------------------------------------------------------------------=#

export viewlabspace

"""
    viewlabspace(L=50)

Return a CairoMakie figure showing the a*–b* slice of CIELAB colour space at
lightness `L` (0–100). Colours outside the RGB gamut are shown in black;
reference colours and their Lab coordinates are labelled.

The figure can be displayed with `display(fig)` or saved with
`CairoMakie.save("labslice.png", fig)`. Call the function again for another
lightness; it does not wait for terminal input.

The old `viewlabspace(L, figNo)` form is deprecated. Figure numbers are no
longer used; each call returns a new figure.

See also: cmap
"""
function viewlabspace(L::Real=50)
    isfinite(L) && 0 <= L <= 100 || throw(ArgumentError("Lightness must be between 0 and 100"))
    coords = -127:0.5:127
    pixels = labslice(L, coords)
    reference = srgb2lab([1.0 0 0; 0 1 0; 0 0 1; 1 1 0; 0 1 1; 1 0 1])
    names = ("red", "green", "blue", "yellow", "cyan", "magenta")

    fig = CairoMakie.Figure(size=(850, 800))
    ax = CairoMakie.Axis(fig[1, 1]; xlabel="a*", ylabel="b*",
        title=@sprintf("Lab space: Lightness %.1f", L), aspect=CairoMakie.DataAspect(),
        xticks=-100:50:100, yticks=-100:50:100)
    # Makie indexes images by x then y, so a* increases rightwards and b* upwards.
    bounds = (first(coords) - step(coords)/2, last(coords) + step(coords)/2)
    CairoMakie.image!(ax, bounds, bounds, pixels; interpolate=false)
    CairoMakie.scatter!(ax, [0.0], [0.0]; marker=:+, color=:red, markersize=16)
    for (i, name) in enumerate(names)
        a, b = reference[i, 2], reference[i, 3]
        CairoMakie.scatter!(ax, [a], [b]; marker=:+, color=:white, markersize=16)
        # Put labels to the left near the right edge of the slice.
        rightedge = a > 60
        CairoMakie.text!(ax, a, b;
            text=@sprintf("%s\n%.0f %.0f %.0f", name, reference[i, 1], a, b),
            color=:white, fontsize=14, strokecolor=:black, strokewidth=0.5,
            align=(rightedge ? :right : :left, :center),
            offset=(rightedge ? -10 : 10, 0))
    end
    CairoMakie.xlims!(ax, bounds...)
    CairoMakie.ylims!(ax, bounds...)
    return fig
end

function viewlabspace(L::Real, figNo::Integer)
    Base.depwarn("viewlabspace(L, figNo) is deprecated; call viewlabspace(L) and use the returned figure.",
                 :viewlabspace)
    return viewlabspace(L)
end

# Generate an image in Makie's (a*, b*) order. Preserve the existing round-trip
# Lab tolerance of 2 when masking colours outside the displayable RGB gamut.
function labslice(L, coords)
    lab = Array{Float64}(undef, length(coords), length(coords), 3)
    for j in eachindex(coords), i in eachindex(coords)
        lab[i, j, 1] = L
        lab[i, j, 2] = coords[i]
        lab[i, j, 3] = coords[j]
    end
    rgb = lab2srgb(lab)
    reconstructed = srgb2lab(rgb)
    pixels = ColorTypes.RGB.(rgb[:, :, 1], rgb[:, :, 2], rgb[:, :, 3])
    for j in axes(pixels, 2), i in axes(pixels, 1)
        if maximum(abs(lab[i, j, c] - reconstructed[i, j, c]) for c in 1:3) >= 2
            pixels[i, j] = ColorTypes.RGB(0, 0, 0)
        end
    end
    return pixels
end
