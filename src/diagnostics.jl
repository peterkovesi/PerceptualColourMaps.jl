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

# Diagnostic plotting is kept separate from colour map equalisation so that
# drawing a figure cannot change the numerical result.

# Images use (row, column, channel); Makie images use (x, y).
function diagnosticimage(rgb)
    pixels = ColorTypes.RGB.(rgb[:, :, 1], rgb[:, :, 2], rgb[:, :, 3])
    return permutedims(pixels)
end

function diagnosticfigures(rgbmap, newrgbmap, newlabmap,
                           initialcumdE, initialdeltaE, newdeltaE, formula, W)
    N = size(newrgbmap, 1)
    indices = 1:N
    sr = sineramp()

    comparison = CairoMakie.Figure(size=(1000, 1100))
    for (row, map, title) in ((1, rgbmap, "Unequalised colour map"),
                              (2, newrgbmap, "Equalised colour map"))
        ax = CairoMakie.Axis(comparison[row, 1]; title=title,
                            aspect=CairoMakie.DataAspect(), yreversed=true)
        CairoMakie.image!(ax, diagnosticimage(applycolourmap(sr, map)); interpolate=false)
        CairoMakie.hidedecorations!(ax)
        CairoMakie.hidespines!(ax)
    end

    contrast = CairoMakie.Figure(size=(1000, 650))
    cumulative = CairoMakie.Axis(contrast[1, 1]; xlabel="Colour map index",
        ylabel="Cumulative dE",
        title=@sprintf("Cumulative %s change in input colour map\nWeights [%.1f  %.1f  %.1f]",
                       formula, W[1], W[2], W[3]))
    # CIE76 returns vectors; CIEDE2000 returns N×1 matrices. Makie line
    # coordinates must be vectors for either colour-difference formula.
    CairoMakie.lines!(cumulative, indices, vec(initialcumdE))
    CairoMakie.xlims!(cumulative, 1, N)
    CairoMakie.ylims!(cumulative, 0, 1.05 * maximum(initialcumdE))

    differences = CairoMakie.Axis(contrast[2, 1]; xlabel="Colour map index", ylabel="dE",
        title="Raw and corrected $formula differences along the designed Lab path")
    CairoMakie.lines!(differences, indices, vec(initialdeltaE); label="Original colour map")
    CairoMakie.lines!(differences, indices, vec(newdeltaE); label="Adjusted colour map")
    CairoMakie.xlims!(differences, 1, N)
    # Include both curves, even if smoothing raises the corrected maximum.
    CairoMakie.ylims!(differences, 0,
                     1.05 * max(maximum(initialdeltaE), maximum(newdeltaE), eps()))
    CairoMakie.Legend(contrast[2, 2], differences; tellheight=false)

    components = CairoMakie.Figure(size=(1000, 900))
    rgbaxis = CairoMakie.Axis(components[1, 1]; xlabel="Colour map index",
                             title="RGB values along colour map")
    labaxis = CairoMakie.Axis(components[2, 1]; xlabel="Colour map index",
                             title="Designed L* a* b* values along colour map")
    erroraxis = CairoMakie.Axis(components[3, 1]; xlabel="Colour map index",
        title="Desired minus achieved L* a* b* values (gamut clipping)")
    gamuterror = newlabmap - srgb2lab(newrgbmap)
    for (channel, rgbname, rgbcolour, labname) in
        ((1, "Red", :red, "Lightness"), (2, "Green", :green, "a*"), (3, "Blue", :blue, "b*"))
        CairoMakie.lines!(rgbaxis, indices, newrgbmap[:, channel]; label=rgbname, color=rgbcolour)
        CairoMakie.lines!(labaxis, indices, newlabmap[:, channel]; label=labname)
        CairoMakie.lines!(erroraxis, indices, gamuterror[:, channel]; label=labname)
    end
    CairoMakie.ylims!(rgbaxis, 0, 1.1)
    CairoMakie.ylims!(labaxis, min(-100, minimum(newlabmap)), max(100, maximum(newlabmap)))
    # Avoid identical limits for maps with no gamut clipping.
    maxerror = max(maximum(abs, gamuterror), 1e-6)
    CairoMakie.ylims!(erroraxis, -1.05 * maxerror, 1.05 * maxerror)
    for (row, ax) in enumerate((rgbaxis, labaxis, erroraxis))
        CairoMakie.xlims!(ax, 1, N)
        CairoMakie.Legend(components[row, 2], ax; tellheight=false)
    end

    return (comparison, contrast, components)
end
