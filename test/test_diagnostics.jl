import CairoMakie
using Colors: RGB, Lab

# Capture the public diagnostics=true display path without opening a viewer.
struct DiagnosticDisplay <: AbstractDisplay
    figures::Vector{CairoMakie.Figure}
end
Base.display(d::DiagnosticDisplay, fig::CairoMakie.Figure) = push!(d.figures, fig)
Base.displayable(::DiagnosticDisplay, ::MIME"image/png") = true

@testset "CairoMakie diagnostics" begin
    figures = CairoMakie.Figure[]
    capture = fig -> push!(figures, fig)

    for label in ("L3", "D1", "C2", "I1")
        empty!(figures)
        expected = cmap(label; N=32, returnname=true)
        actual = cmap(label; N=32, returnname=true, diagnostics=capture)
        @test actual == expected
        @test length(figures) == 3
        @test [count(x -> x isa CairoMakie.Axis, fig.content) for fig in figures] == [2, 2, 3]
    end

    # Enabling diagnostics must not change shift/reverse or colour-map metadata.
    @test cmap("C2"; N=32, shift=0.25, reverse=true, returnname=true, diagnostics=capture) ==
          cmap("C2"; N=32, shift=0.25, reverse=true, returnname=true)

    empty!(figures)
    recorder = DiagnosticDisplay(figures)
    pushdisplay(recorder)
    try
        expected = cmap("L3")
        @test isempty(figures)
        @test cmap("L3"; diagnostics=true) == expected
        @test length(figures) == 3
    finally
        popdisplay(recorder)
    end

    # Render all seven panels without a display server, in raster and vector form.
    mktempdir() do dir
        for (i, fig) in enumerate(figures), extension in ("png", "svg")
            path = joinpath(dir, "diagnostic-$i.$extension")
            CairoMakie.save(path, fig)
            @test filesize(path) > 1000
        end
    end

    # The CIEDE2000 path and the RGB/RGBA overloads must forward the callback too.
    lab = hcat(collect(range(10.0, 90.0; length=16)), zeros(16), zeros(16))
    empty!(figures)
    @test equalisecolourmap("LAB", lab, "CIEDE2000", [1, 1, 1], 0, false, capture) ==
          equalisecolourmap("LAB", lab, "CIEDE2000", [1, 1, 1])
    @test length(figures) == 3
    rgba = cmap("L1"; N=16)
    for map in (rgba, RGB{Float64}.(rgba), RGBA2FloatArray(rgba))
        empty!(figures)
        @test equalizecolormap("RGB", map, "CIE76", [1, 0, 0], 0, false, capture) ==
              equalisecolourmap("RGB", map)
        @test length(figures) == 3
    end

    # An asymmetric image catches an accidental swap of rows and columns.
    rgb = zeros(2, 3, 3)
    rgb[1, 3, 1] = 1
    rgb[2, 1, 3] = 1
    pixels = PerceptualColourMaps.diagnosticimage(rgb)
    @test size(pixels) == (3, 2)
    @test pixels[3, 1] == RGB(1, 0, 0)
    @test pixels[1, 2] == RGB(0, 0, 1)
    comparisonaxis = first(filter(x -> x isa CairoMakie.Axis, figures[1].content))
    @test comparisonaxis.yreversed[]
end

@testset "Lab colour-space slices" begin
    for L in (-1, 101, NaN, Inf)
        @test_throws ArgumentError viewlabspace(L)
    end
    for L in (0, 50, 100)
        fig = viewlabspace(L)
        @test fig isa CairoMakie.Figure
    end
    @test_deprecated viewlabspace(50, 1)

    # Check a*/b* orientation and preserve the neutral centre and gamut mask.
    coords = -100:50:100
    pixels = PerceptualColourMaps.labslice(50, coords)
    @test pixels[3, 3] ≈ convert(RGB, Lab(50, 0, 0))
    @test pixels[4, 3] ≈ convert(RGB, Lab(50, 50, 0))
    @test pixels[3, 4] ≈ convert(RGB, Lab(50, 0, 50))
    @test pixels[1, 1] == RGB(0, 0, 0)

    mktempdir() do dir
        fig = viewlabspace()
        for extension in ("png", "svg")
            path = joinpath(dir, "labslice.$extension")
            CairoMakie.save(path, fig)
            @test filesize(path) > 1000
        end
    end
end
