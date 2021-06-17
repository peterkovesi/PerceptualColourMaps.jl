#=----------------------------------------------------------------------------

Copyright (c) 2015-2020 Peter Kovesi
peterkovesi.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

The Software is provided "as is", without warranty of any kind.

----------------------------------------------------------------------------=#

export cmap, equalisecolourmap, equalizecolormap, linearrgbmap
export lab2srgb, srgb2lab, RGBA2UInt32
export RGB2FloatArray, RGBA2FloatArray
export FloatArray2RGB, FloatArray2RGBA

import Images, PyPlot
import Images.ColorTypes, Images.Colors
using Interpolations

# There seems to be a fatal clash between PyPlot and Tk.  ImageView
# and Winston use Tk so unfortunately they have been excluded and all
# graphics done via PyPlot

#----------------------------------------------------------------------------

# Type for defining colour maps for storage in a dictionary

mutable struct colourmapdef
    name::String
    hueStr::String
    attributeStr::String
    desc::String
    colourspace::String
    colpts::Array{Float64,2}
    splineorder::Int
    formula::String
    W::Array{Float64,1}
    sigma::Float64
end

# Convenience constructor
function newcolourmapdef(;
     name::String="",
     hueStr::String="",
     attributeStr::String="",
     desc::String="",
     colourspace::String="",
     colpts::Array{T1,2}=[0 0 0],
     splineorder::Int=2,
     formula="CIE76",
     W::Array{T2,1}=[1.0,0.0,0.0],
     sigma::T3=0.0) where {T1<:Real, T2<:Real, T3<:Real}

    return colourmapdef(name, hueStr, attributeStr, desc,
                        colourspace, float(colpts), splineorder,
                        formula, float(W), float(sigma))
end

#---------------------------------------------------------------------------

"""
cmap:  Library of perceptually uniform colour maps

Most of these colour maps have been designed to have constant a
magnitude of lightness gradient.  At fine spatial frequencies
perceptual contrast is dominated by *lightness* difference, chroma and
hue are relatively unimportant.

```
Usage:  1:  map = cmap(I, keyword_params ...)
        2:  (map, name, desc) = cmap(I, keyword_params ..., returnname=true)
        3:  cmap(searchStr)
        4:  cmap()

Arguments for Usage 1 and 2:

            I - A string label indicating the colour map to be generated or a
                string specifying a colour map name or attribute to search
                for.  Type 'cmap()' with no arguments to get a full list of
                possible colour maps and their corresponding labels.

  labels:  "L1" - "L20"  for linear maps
           "D1" - "D13"  for diverging maps
           "C1" - "C11"  for cyclic maps
           "R1" - "R4"   for rainbow maps
           "I1" - "I3"   for isoluminant maps

  labels for generating maps for the colour blind:
           "CBL1"  - "CBL4" Linear maps for protanopic and deuteranopic viewers.
           "CBD1"  - "CBD2" Diverging maps for protanopic and deuteranopic viewers.
           "CBC1"  - "CBC2" Cyclic maps for protanopic and deuteranopic viewers.
           "CBTL1" - "CBTL4" Linear maps for tritanopic viewers.
           "CBTD1" - Diverging map for tritanopic viewers.
           "CBTC1" - "CBTC2" Cyclic maps for tritanopic viewers.


 Some colour maps have alternate labels for convenience and readability.

   map = cmap("L1")  or map = cmap("grey")  will produce a linear grey map.
   cmap()  lists all colour maps and labels.

 Possible keyword parameter options:

    chromaK::Real - The scaling to apply to the chroma values of the colour map,
                    0 - 1.  The default is 1 giving a fully saturated colour map
                    as designed. However, depending on your application you may
                    want a colour map with reduced chroma/saturation values.
                    You can use values greater than 1 however gamut clipping is
                    likely to occur giving rise to artifacts in the colour map.
           N::Int - Number of values in the colour map. Defaults to 256.
      shift::Real - Fraction of the colour map length N that the colour map is
                    to be cyclically rotated, may be negative.  (Should only be
                    applied to cyclic colour maps!). Defaults to 0.
    reverse::Bool - If true reverses the colour map. Defaults to false.
diagnostics::Bool - If true displays various diagnostic plots. Note the
                    diagnostic plots will be for the map _before_ any cyclic
                    shifting or reversing is applied. Defaults to false.
 returnname::Bool - If true the function returns a tuple of the colourmap, its
                    name and its description  (colourmap, name, description)
                    The default value is false, just the colourmap is returned.

Returns:
          map - Array of ColorTypes.RGBA{Float64,1} giving the rgb colour map.

     If returnname=true the function additionally returns
         name - A string giving a nominal name for the colour map
         desc - A string giving a brief description of the colour map
```

Usage 3 and 4:  cmap(searchStr)

Given the large number of colour maps that this function can create this usage
option provides some help by listing the numbers of all the colour maps with
names containing the string 'str'.  Typically this is used to search for
colour maps having a specified attribute: "linear", "diverging", "rainbow",
"cyclic", or "isoluminant" etc.  If 'searchStr' is omitted all colour maps are
listed.

```
   cmap()              # lists all colour maps
   cmap("diverging")   # lists all diverging colour maps
```
Note the listing of colour maps can be a bit slow because each colour map has to
be created in order to determine its full name.

**Using the colour maps:**

PyPlot:
```
> using PyPlot
> sr = sineramp();    # Generate the sineramp() colour map test image.
> imshow(sr);         # Display with matplotlib's default 'jet' colour map.
                      # Note the perceptual dead spots in the map.
> imshow(sr, cmap = ColorMap(cmap("L3"))); # Apply the cmap() heat colour map.
```

Plots:
```
> using Plots
> y=rand(100);
> Plots.scatter(y, zcolor=y, marker=ColorGradient(cmap("R3")));
```

You can also apply a colour map to a single channel image to create a
conventional RGB image. This is recommended if you are using a
diverging or cyclic colour map because it allows you to ensure data
values are honoured appropriately when you map them to colours.

```
  Apply the L4 heat colour map to the test image
> rgbimg = applycolourmap(sr, cmap("L4"));

  Apply a diverging colour map to the test image using 127 as the
  value that is associated with the centre point of the diverging
  colour map
> rgbimg = applydivergingcolourmap(sr, cmap("D1"),127);

  Apply a cyclic colour map to the circlesineramp() test image specifying
  a data cyclelength of 2*pi.
> (cr,) = circlesineramp();   # Generate a cyclic colour map test image.
> rgbimg = applycycliccolourmap(cr, cmap("C1"), cyclelength=2*pi);

> ImageView.view(rgbimg)      # Display the image with ImageView
> PyPlot.imshow(rgbimg)       # or with PyPlot
```
*Warning* PyPlot and Tk do not seem to coexist very well (Julia can
crash!).  ImageView and Winston use Tk which means that you may have
to take care which image display functions you choose to use.


**Colour Map naming convention:**

```
                    linear_kryw_5-100_c67_n256
                      /      /    |    \\    \\
  Colour Map attribute(s)   /     |     \\   Number of colour map entries
                           /      |      \\
     String indicating nominal    |      Mean chroma of colour map
     hue sequence.                |
                              Range of lightness values
```
In addition, the name of the colour map may have cyclic shift information
appended to it, it may also have a flag indicating it is reversed.

```
              cyclic_wrwbw_90-40_c42_n256_s25_r
                                          /    \\
                                         /   Indicates that the map is reversed.
                                        /
                  Percentage of colour map length
                  that the map has been rotated by.
```
* Attributes may be: linear, diverging, cyclic, rainbow, or isoluminant.  A
colour map may have more than one attribute. For example, diverging-linear or
cyclic-isoluminant.

* Lightness values can range from 0 to 100. For linear colour maps the two
lightness values indicate the first and last lightness values in the
map. For diverging colour maps the second value indicates the lightness value
of the centre point of the colour map (unless it is a diverging-linear
colour map). For cyclic and rainbow colour maps the two values indicate the
minimum and maximum lightness values. Isoluminant colour maps have only
one lightness value.

* The string of characters indicating the nominal hue sequence uses
the following code

```
      r - red      g - green      b - blue
      c - cyan     m - magenta    y - yellow
      o - orange   v - violet
      k - black    w - white      j - grey
```
('j' rhymes with grey). Thus a 'heat' style colour map would be indicated by
the string 'kryw'. If the colour map is predominantly one colour then the
full name of that colour may be used. Note these codes are mainly used to
indicate the hues of the colour map independent of the lightness/darkness and
saturation of the colours.

* Mean chroma/saturation is an indication of vividness of the colour map. A
value of 0 corresponds to a greyscale. A value of 50 or more will indicate a
vivid colour map.

Adding your own colour maps is straightforward. See comments within
the code for instructions for doing this.

Reference: Peter Kovesi. Good Colour Maps: How to Design
Them. [arXiv:1509.03700 [cs.GR] 2015](https://arXiv:1509.03700)

See also: equalisecolourmap, viewlabspace, sineramp, circlesineramp,
applycolourmap, applycycliccolourmap, applydivergingcolourmap

"""
function cmap()
    #=----------------------------------------------------------------------------

    Adding your own colour maps is done by adding a new dictionary entry
    to the code blow.   Note that you must use uppercase keys in the dictionary

    1) Colour maps are almost invariably defined via a spline path through CIELAB
       colourspace.  Use viewlabspace() to work out the positions of the spline
       control points in CIELAB space to achieve the colour map path you desire.
       These are stored in an array 'colpts' with columns corresponding to L a and
       b.  If desired the path can be specified in terms of RGB space by setting
       'colourspace' to 'RGB'.  See the ternary colour maps as an example.  Note
       the case expression for the colour map key/label must be upper case.

    2) Set 'splineorder' to 2 for a linear spline segments. Use 3 for a quadratic
       b-spline.

    3) If the colour map path has lightness gradient reversals set 'sigma' to a
       value of around 5 to 7 to smooth the gradient reversal.

    4) If the colour map is of very low lightness contrast, or isoluminant, set
       the lightness, a and b colour difference weight vector W to [1 1 1].
       See equalisecolourmap() for more details

    5) Set the attribute and hue sequence strings ('attributeStr' and 'hueStr')
       appropriately so that a colour map name can be generated.  Note that if you
       are constructing a cyclic colour map it is important that 'attributeStr'
       contains the word 'cyclic'.  This ensures that a periodic b-spline is used
       and also ensures that smoothing is applied in a cyclic manner.  Setting the
       description string is optional.

    6) Run cmap() specifying the key/label you have given your new colour map
       with the diagnostics flag set to one.  Various plots are generated
       allowing you to check the perceptual uniformity, colour map path,
       and any gamut clipping of your colour map.

    Reference: Peter Kovesi. Good Colour Maps: How to Design Them.
    arXiv:1509.03700 [cs.GR] 2015.

    October  2015 - Ported to Julia from MATLAB
    December 2015 - Tweaked control points for some colour maps to keep them in gamut
    November 2016 - Compatibility with 0.5, Mods to heat colour map
    June     2018 - Updated and added some colour maps
    November 2020 - Added C10, C11, slight tweak to L16, 2-digit naming allowed for.
    December 2020 - Added L20, 'Gouldian'

    ----------------------------------------------------------------------------=#
    cmap("all")    # List all colour maps available
end

function cmap(I::AbstractString; N::Int=256, chromaK::Real=1, shift::Real = 0,
              reverse::Bool = false, diagnostics::Bool = false, returnname::Bool = false)


    # Definitions of key angles in Lab space for defining colours in colour
    # blind colour spaces. Angles are in degrees.
    yellow575 =  92.62  # For protanopic and deuteranopic colour space.
    blue475   = -79.27

    red660  =   32.36   # For tritanopic colour space.
    cyan485 = -138.73


    I = uppercase(I)  # This means you must use uppercase keys in the dictionary

    # ---------- Build dictionary of colour map definitions ----------------

    ## Linear series

    # Grey scale
    cmapdef = Dict("L1" =>
                   newcolourmapdef(desc = "Grey scale",
                                   hueStr = "grey",
                                   attributeStr = "linear",
                                   colourspace = "LAB",
                                   colpts = [0 0 0
                                             100 0 0],
                                   splineorder = 2,
                                   formula = "CIE76",
                                   W = [1, 0, 0],
                                   sigma = 0))

    push!(cmapdef, "GREY" => cmapdef["L1"])  # Convenience name
    push!(cmapdef, "GRAY" => cmapdef["L1"])  # Convenience name
    push!(cmapdef, "L01" => cmapdef["L1"])    # Convenience name

    #  Grey 10 - 95  "REDUCEDGREY"
    push!(cmapdef, "L2" =>
          newcolourmapdef(desc = "Grey scale with slightly reduced contrast " *
                                 "to avoid display saturation problems",
                          hueStr = "grey",
                          attributeStr = "linear",
                          colourspace = "LAB",
                          colpts = [10 0 0
                                    95 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "REDUCEDGREY" => cmapdef["L2"])
    push!(cmapdef, "REDUCEDGRAY" => cmapdef["L2"])
    push!(cmapdef, "L02" => cmapdef["L2"])

    # HEATWHITE
    # Heat map from straight line segments from black to red to yellow
    # to white but with the corners at red and yellow rounded off.
    # Works well
    push!(cmapdef, "L3" =>
          newcolourmapdef(desc = "Black-Red-Yellow-White heat colour map",
                          hueStr = "kryw",
                          attributeStr = "linear",
                          colourspace = "RGB",
                          colpts = [0.0  0.0  0.0
                                    0.85 0.0  0.0
                                    1.0  0.15 0.0
                                    1.0  0.85 0.0
                                    1.0  1.0  0.15
                                    1.0  1.0  1.0 ],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "HEAT" => cmapdef["L3"])  # Convenience name
    push!(cmapdef, "L03" => cmapdef["L3"])

    # "HEATYELLOW"
    push!(cmapdef, "L4" =>
          newcolourmapdef(desc = "Black-Red-Yellow heat colour map",
                          hueStr = "kry",
                          attributeStr = "linear",
                          colourspace = "RGB",
                          colpts = [0.0  0.0  0.0
                                    0.85 0.0  0.0
                                    1.0  0.15 0.0
                                    1.0  1.0  0.0 ],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0.0))

    push!(cmapdef, "HEATYELLOW" => cmapdef["L4"])  # Convenience name
    push!(cmapdef, "L04" => cmapdef["L4"])

    push!(cmapdef, "L5" =>
          newcolourmapdef(desc = "Colour map along the green edge of CIELAB space",
                          hueStr = "green",
                          attributeStr = "linear",
                          colourspace = "LAB",
                          colpts = [ 5 -9  5
                                     15 -23 20
                                     25 -31 31
                                     35 -39 39
                                     45 -47 47
                                     55 -55 55
                                     65 -63 63
                                     75 -71 71
                                     85 -79 79
                                     95 -38 90] ,
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0.0))

    push!(cmapdef, "L05" => cmapdef["L5"])
    
    push!(cmapdef, "L6" =>
          newcolourmapdef(desc = "Blue shades running vertically up the blue edge of CIELAB space",
                          attributeStr = "linear",
                          hueStr = "blue",
                          colourspace = "LAB",
                          colpts = [ 5  31 -45
                                     15 50 -66
                                     25 65 -90
                                     35 70 -100
                                     45 45 -85
                                     55  20 -70
                                     65  0 -53
                                     75 -22 -37
                                     85 -38 -20
                                     95 -25 -3],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "L06" => cmapdef["L6"])
    
    push!(cmapdef, "L7" =>
          newcolourmapdef(desc = "Blue-Pink-Light Pink colour map",
                          attributeStr = "linear",
                          hueStr = "bmw",
                          colourspace = "LAB",
                          colpts = [ 5 29 -43
                                     15 48 -66
                                     25 64 -89
                                     35 73 -100
                                     45 81 -86
                                     55 90 -69
                                     65 83 -53
                                     75 56 -36
                                     85 32 -22
                                     95 10 -7],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "L07" => cmapdef["L7"])
    
    push!(cmapdef, "L8" =>
          newcolourmapdef(desc = "Blue-Magenta-Orange-Yellow highly saturated colour map",
                          attributeStr = "linear",
                          hueStr = "bmy",
                          colourspace = "LAB",
                          colpts = [10 ch2ab(55,-58)
                                    20 ch2ab(75,-58)
                                    30 ch2ab(75,-40)
                                    40 ch2ab(73,-20)
                                    50 ch2ab(75,  0)
                                    60 ch2ab(70, 30)
                                    70 ch2ab(65, 60)
                                    80 ch2ab(75, 80)
                                    95 ch2ab(80, 105)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "BMY" => cmapdef["L8"])  # Convenience name
    push!(cmapdef, "L08" => cmapdef["L8"])
    
    # Blue to yellow section of R1 with short extensions at each end
    push!(cmapdef, "L9" =>
          newcolourmapdef(desc = "Blue to yellow colour map",
                          attributeStr = "linear",
                          hueStr = "bgyw",
                          colourspace = "LAB",
                          colpts = [20  59 -80
                                    35  28 -66
                                    45 -14 -29
                                    60 -62  60
                                    85 -10  85
                                    95 -15  70
                                    98   0   0],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "BGYW" => cmapdef["L9"])  # Convenience name
    push!(cmapdef, "L09" => cmapdef["L9"])
    
   # GEOGRAPHIC1
    push!(cmapdef, "L10" =>
          newcolourmapdef(desc = "A 'geographical' colour map.  " *
                          "Best used with relief shading",
                          attributeStr = "linear",
                          hueStr = "gow",
                          colourspace = "LAB",
                          colpts = [60 ch2ab(20, 180)   # pale blue green
                                    65 ch2ab(30, 135)
                                    70 ch2ab(35, 75)
                                    75 ch2ab(45, 85)
                                    80 ch2ab(22, 90)
                                    85 0 0   ],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

     push!(cmapdef, "GEOGRAPHIC1" => cmapdef["L10"])  # convenience name

     # GEOGRAPHIC2 Lighter version of L10 with a bit more chroma
     push!(cmapdef, "L11" =>
          newcolourmapdef(desc = "A lighter 'geographical' colour map.  " *
                          "Best used with relief shading",
                          attributeStr = "linear",
                          hueStr = "gow",
                          colourspace = "LAB",
                          colpts = [65 ch2ab(50, 135)   # pale blue green
                                    75 ch2ab(45, 75)
                                    80 ch2ab(45, 85)
                                    85 ch2ab(22, 90)
                                    90 0 0   ],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

     push!(cmapdef, "GEOGRAPHIC2" => cmapdef["L11"])  # convenience name

    #  "DEPTH"
    push!(cmapdef, "L12" =>
          newcolourmapdef(desc =  "A 'water depth' colour map",
                          attributeStr = "linear",
                          hueStr = "blue",
                          colourspace = "LAB",
                          colpts = [95 0 0
                                    80 ch2ab(20, -95)
                                    70 ch2ab(25, -95)
                                    60 ch2ab(25, -95)
                                    50 ch2ab(35, -95) ],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "DEPTH" => cmapdef["L12"])  # convenience name

    # The following three colour maps are for ternary images, eg Landsat images
    # and radiometric images.  These colours form the nominal red, green and
    # blue 'basis colours' that are used to form the composite image.  They are
    # designed so that they, and their secondary colours, have nearly the same
    # lightness levels and comparable chroma.  This provides consistent feature
    # salience no matter what channel-colour assignment is made.  The colour
    # maps are specified as straight lines in RGB space.  For their derivation
    # see
    # https://arxiv.org/abs/1509.03700

    # "REDTERNARY"
    push!(cmapdef, "L13" =>
          newcolourmapdef(desc = "red colour map for ternary images",
                          attributeStr = "linear",
                          hueStr = "ternary-red",
                          colourspace = "RGB",
                          colpts = [0.00 0.00 0.00
                                    0.90 0.17 0.00],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "REDTERNARY" => cmapdef["L13"])

    # "GREENTERNARY"
    push!(cmapdef, "L14" =>
          newcolourmapdef(desc = "green colour map for ternary images",
                          attributeStr = "linear",
                          hueStr = "ternary-green",
                          colourspace = "RGB",
                          colpts = [0.00 0.00 0.00
                                    0.00 0.50 0.00],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "GREENTERNARY" => cmapdef["L14"])

    # "BLUETERNARY"
    push!(cmapdef, "L15" =>
          newcolourmapdef(desc = "blue colour map for ternary images",
                          attributeStr = "linear",
                          hueStr = "ternary-blue",
                          colourspace = "RGB",
                          colpts = [0.00 0.00 0.00
                                    0.10 0.33 1.00],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "BLUETERNARY" => cmapdef["L15"])

    # Variation of L9  Black - Blue - green - yellow - white.  Works well.
    push!(cmapdef, "L16" =>
          newcolourmapdef(desc = "Black-Blue-Green-Yellow-White colour map",
                          attributeStr = "linear",
                          hueStr = "kbgyw",
                          colourspace = "LAB",
                          colpts = [ 10   0   0
                                     20  59 -80
                                     35  28 -66
                                     45 -14 -29
                                     60 -62  60
                                     85 -10  85
                                     95 -15  70
                                     98   0   0],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # Map with linear decreasing lightness, increasing chroma to blue.
    # Precompute a spiral of increasing chroma down through Lab space
    nsteps = 12
    ang1 = 120; ang2 = -60   # Linearly interpolate hue angle
    ang = range(ang1, stop=ang2, length=nsteps)

    # Interpolate chroma but use a 'gamma' of 0.5 to keep the colours more saturated.
    sat1 = 0; sat2 = 80
    sat =  (range(sat1, stop=sat2, length=nsteps)/sat2).^0.5 * sat2

    l1 = 100; l2 = 25        # Linearly interpolate lightness
    l = range(l1, stop=l2, length=nsteps)

    colptarray = zeros(nsteps,3)
    for n=1:nsteps
        colptarray[n,:] = [l[n]  ch2ab(sat[n], ang[n])]
    end

    push!(cmapdef, "L17" =>
          newcolourmapdef(desc = "White-Orange-Red-Blue, decreasing lightness with increasing saturation",
                          attributeStr = "linear",
                          hueStr = "worb",
                          colourspace = "LAB",
                          colpts = colptarray,
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # White-Yellow-Orange-Red, decreasing lightness with increasing saturation
    # Precompute a spiral of increasing chroma down through Lab space
    nsteps = 12
    ang1 = 120; ang2 = 35
    ang = range(ang1, stop=ang2, length=nsteps)

    sat1 = 0; sat2 = 84
    sat =  (range(sat1, stop=sat2, length=nsteps)/sat2).^0.5 * sat2

    l1 = 100; l2 = 45
    l = range(l1, stop=l2, length=nsteps)

    colptarray = zeros(nsteps,3)
    for n=1:nsteps
        colptarray[n,:] = [l[n]  ch2ab(sat[n], ang[n])]
    end

    push!(cmapdef, "L18" =>
          newcolourmapdef(desc = "White-Yellow-Orange-Red, decreasing lightness with increasing saturation",
                          attributeStr = "linear",
                          hueStr = "wyor",
                          colourspace = "LAB",
                          colpts = colptarray,
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # White-Cyan-Magenta-Red, decreasing lightness with increasing saturation
    # Precompute a spiral of increasing chroma down through Lab space
    nsteps = 12
    ang1 = -140; ang2 = 40
    ang = range(ang1, stop=ang2, length=nsteps)

    sat1 = 0; sat2 = 84
    sat =  (range(sat1, stop=sat2, length=nsteps)/sat2).^0.5 * sat2

    l1 = 100; l2 = 45
    l = range(l1, stop=l2, length=nsteps)

    colptarray = zeros(nsteps,3)
    for n=1:nsteps
        colptarray[n,:] = [l[n]  ch2ab(sat[n], ang[n])]
    end

    push!(cmapdef, "L19" =>
          newcolourmapdef(desc = "White-Cyan-Magenta-Red, decreasing lightness with increasing saturation",
                          attributeStr = "linear",
                          hueStr = "wcmr",
                          colourspace = "LAB",
                          colpts = colptarray,
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))


    # A map inspired by MATLAB's Parula but with a smoother path that does not
    # attempt to include cyan and maintains a more uniform slope upwards in LAB
    # space.  It also starts at a dark grey with a lightness of 20. It works very
    # much better than Parula!
    push!(cmapdef, "L20" =>
          newcolourmapdef(desc = "Black-Blue-Green-Orange-Yellow map",
                          attributeStr = "linear",
                          hueStr = "kbgoy",
                          colourspace = "LAB",
                          colpts = [20 0  0
                                    40 55 -90 
                                    55 -47 0 
                                    70 -20 70
                                    80  20 80
                                    95 -21 92],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "GOULDIAN" => cmapdef["L20"])
    

    #--------------------------------------------------------------------------------
    ## Diverging colour maps

    # Note that on these colour maps often we do not go to full white but use a
    # lightness value of 95. This helps avoid saturation problems on monitors.
    # A lightness smoothing sigma of 5 to 7 is used to avoid generating a false
    # feature at the white point in the middle.  Note however, this does create
    # a small perceptual contrast blind spot at the middle.

    push!(cmapdef, "D1" =>
          newcolourmapdef(desc = "Diverging blue-white-red colour map",
                          attributeStr = "diverging",
                          hueStr = "bwr",
                          colourspace = "LAB",
                          colpts = [40  ch2ab(83,-64)
                                    95  0   0
                                    40  ch2ab(83, 39)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "COOLWARM" => cmapdef["D1"])
    push!(cmapdef, "D01" => cmapdef["D1"])

    # Variation on D1 with darker end point colours
    push!(cmapdef, "D1A" =>
          newcolourmapdef(desc = "Diverging blue-white-red colour map",
                          attributeStr = "diverging",
                          hueStr = "bwr",
                          colourspace = "LAB",
                          colpts = [20  ch2ab(49, -64)
                                    40  ch2ab(83, -64)
                                    65  ch2ab(60, -64)
                                    95  0   0
                                    65  ch2ab(60, 37)
                                    40  ch2ab(83, 37)
                                    20  ch2ab(49, 37)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "D01A" => cmapdef["D1A"])
    
    push!(cmapdef, "D2" =>
          newcolourmapdef(desc = "Diverging green-white-violet colour map",
                          attributeStr = "diverging",
                          hueStr = "gwv",
                          colourspace = "LAB",
                          colpts = [55 -50  55
                                    95   0   0
                                    55  60 -55],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "D02" => cmapdef["D2"])

    push!(cmapdef, "D3" =>
          newcolourmapdef(desc = "Diverging green-white-red colour map",
                          attributeStr = "diverging",
                          hueStr = "gwr",
                          colourspace = "LAB",
                          colpts = [55 -50 55
                                    95   0  0
                                    55  63 39],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "D03" => cmapdef["D3"])

    push!(cmapdef, "D4" =>
          newcolourmapdef(desc = "Diverging blue - black - red colour map",
                          attributeStr = "diverging",
                          hueStr = "bkr",
                          colourspace = "LAB",
                          colpts = [55 ch2ab(70, -76)
                                    10  0   0
                                    55 ch2ab(70, 35)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "D04" => cmapdef["D4"])

    push!(cmapdef, "D5" =>
          newcolourmapdef(desc = "Diverging green - black - red colour map",
                          attributeStr = "diverging",
                          hueStr = "gkr",
                          colourspace = "LAB",
                          colpts = [60 ch2ab(80, 134)
                                    10  0   0
                                    60 ch2ab(80, 40)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "D05" => cmapdef["D5"])

    push!(cmapdef, "D6" =>
          newcolourmapdef(desc = "Diverging blue - black - yellow colour map",
                          attributeStr = "diverging",
                          hueStr = "bky",
                          colourspace = "LAB",
                          colpts = [60 ch2ab(60, -85)
                                    10  0   0
                                    60 ch2ab(60, 85)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "D06" => cmapdef["D6"])

    # Linear diverging  blue - grey - yellow.  Works well
    push!(cmapdef, "D7" =>
          newcolourmapdef(desc = "Diverging blue - grey - yellow colour map. " *
                          "This kind of diverging map has no perceptual dead " *
                          "spot at the centre.",
                          attributeStr = "diverging-linear",
                          hueStr = "bjy",
                          colourspace = "LAB",
                          colpts = [30 ch2ab(89, -59)
                                    60 0 0
                                    90 ch2ab(89, 96)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "DIBBGY" => cmapdef["D7"])
    push!(cmapdef, "D07" => cmapdef["D7"])

    # Linear diverging blue - grey - yellow.  Similar to 'D7' but
    # with slight curves in the path to slightly increase the chroma
    # at the 1/4 and 3/4 locations in the map.
    h1 = -59; h2 = 95  # Set up parameters for defining colours
    mh = (h1+h2)/2
    dh = 10

    push!(cmapdef, "D7B" =>
          newcolourmapdef(desc = "Diverging blue - grey - yellow colour map",
                          attributeStr = "diverging-linear",
                          hueStr = "bjy",
                          colourspace = "LAB",
                          colpts = [30 ch2ab(88, h1)
                                    48 ch2ab(40, h1+dh)
                                    60 0 0
                                    60 0 0
                                    72 ch2ab(40, h2-dh)
                                    90 ch2ab(88, h2)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "D07B" => cmapdef["D7B"])

    push!(cmapdef, "D8" =>
          newcolourmapdef(desc="Linear diverging  blue - grey - red",
                          attributeStr = "diverging-linear",
                          hueStr = "bjr",
                          colourspace = "LAB",
                          colpts = [30 ch2ab(105, -58)
                                    42.5 0 0
                                    55 ch2ab(105, 41)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "D08" => cmapdef["D8"])

    # Lightened version of D1 for relief shading - Good.
    push!(cmapdef, "D9" =>
          newcolourmapdef(desc = "Diverging low contrast blue - red colour map",
                          attributeStr = "diverging",
                          hueStr = "bwr",
                          colourspace = "LAB",
                          colpts = [55  ch2ab(73,-74)
                                    98  0   0
                                    55  ch2ab(73, 39)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 2)) # Less smoothing needed for low contrast

    push!(cmapdef, "D09" => cmapdef["D9"])

    # Low contrast diverging map for when you want to use relief
    # shading
    push!(cmapdef, "D10" =>
          newcolourmapdef(desc = "Diverging low contrast cyan - white - magenta colour map",
                          attributeStr = "diverging",
                          hueStr = "cwm",
                          colourspace = "LAB",
                          colpts = [80 ch2ab(44, -135)
                                    100  0   0
                                    80 ch2ab(44, -30)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))  # No smoothing needed for lightness range of 20

    # Constant lightness diverging map for when you want to use relief
    # shading ? Perhaps lighten the grey so it is not quite
    # isoluminant ?
    push!(cmapdef, "D11" =>
          newcolourmapdef(desc = "Diverging isoluminat lightblue - lightgrey - orange colour map",
                          attributeStr = "diverging-isoluminant",
                          hueStr = "cjo",
                          colourspace = "LAB",
                          colpts = [70 ch2ab(50, -105)
                                    70  0   0
                                    70 ch2ab(50, 45)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 7))

    # Constant lightness diverging map for when you want to use relief
    # shading ? Perhaps lighten the grey so it is not quite
    # isoluminant ?
    push!(cmapdef, "D12" =>
          newcolourmapdef(desc = "Diverging isoluminat lightblue - lightgrey - pink colour map",
                          attributeStr = "diverging-isoluminant",
                          hueStr = "cjm",
                          colourspace = "LAB",
                          colpts = [75 ch2ab(46, -122)
                                    75  0   0
                                    75 ch2ab(46, -30)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 7))

    # Pleasing Blue-White-Green diverging map
    push!(cmapdef, "D13" =>
          newcolourmapdef(desc = "Diverging blue - white - green colour map",
                          attributeStr = "diverging",
                          hueStr = "bwg",
                          colourspace = "LAB",
                          colpts = [20  ch2ab(40, -70)
                                    45  ch2ab(60, -70)
                                    70  ch2ab(50, -70-35)
                                    95  0 0
                                    95  0 0
                                    70  ch2ab(50, 138+35)
                                    45  ch2ab(60, 138)
                                    20  ch2ab(40, 138)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 5))


    #-------------------------------------------------------------------------
    ## Cyclic colour maps

    # I think this is my best zigzag style cyclic map - Good!  Control
    # points are placed so that lightness steps up and down are
    # equalised.  Additional intermediate points are placed to try to
    # even up the 'spread' of the key colours.
    mag = [75 60 -37]
    yel = [75 0 77]
    blu = [35  70 -100]
    red = [35 60 48]

    push!(cmapdef, "C1" =>
          newcolourmapdef(desc="Cyclic magenta-red-yellow-blue-magenta colour map",
                          attributeStr = "cyclic",
                          hueStr = "mrybm",
                          colourspace = "LAB",
                          colpts = [mag
                                    55 70 0
                                    red
                                    55 35 62
                                    yel
                                    50 -20 -30
                                    blu
                                    55 45 -67
                                    mag],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "C01" => cmapdef["C1"])

    # A big diamond across the gamut.  Really good!  Incorporates two
    # extra cotnrol points around blue to extend the width of that
    # segment slightly.
    push!(cmapdef, "C2" =>
          newcolourmapdef(desc="Cyclic magenta-yellow-green-blue-magenta colour map",
                          attributeStr = "cyclic",
                          hueStr = "mygbm",
                          colourspace = "LAB",
                          colpts = [62.5  83 -54
                                    80 20 25
                                    95 -20 90
                                    62.5 -65 62
                                    42 10 -50
                                    30 75 -103
                                    48 70 -80
                                    62.5  83 -54],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "PHASE4" => cmapdef["C2"])
    push!(cmapdef, "C02" => cmapdef["C2"])

    # red-white-blue-black-red allows quadrants to be identified
    push!(cmapdef, "C3" =>
          newcolourmapdef(desc = "Cyclic: white - red - black - blue",
                          attributeStr = "cyclic",
                          hueStr = "wrkbw",
                          colourspace = "LAB",
                          colpts = [90  0   0
                                    50 65  56
                                    10  0   0
                                    50 31 -80
                                    90  0   0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "C03" => cmapdef["C3"])

    # white-red-white-blue-white Works nicely
    push!(cmapdef, "C4" =>
          newcolourmapdef(desc = "Cyclic: white - red - white - blue"  ,
                          attributeStr = "cyclic",
                          hueStr = "wrwbw",
                          colourspace = "LAB",
                          colpts = [90 0 0
                                    40 65 56
                                    90 0 0
                                    40 31 -80
                                    90 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "PHASE2" => cmapdef["C4"])
    push!(cmapdef, "C04" => cmapdef["C4"])

    #  "CYCLICGREY"  Cyclic greyscale  Works well
    push!(cmapdef, "C5" =>
          newcolourmapdef(desc = "Cyclic: greyscale",
                          attributeStr = "cyclic",
                          hueStr = "grey",
                          colourspace = "LAB",
                          colpts = [50 0 0
                                    85 0 0
                                    15 0 0
                                    50 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "C05" => cmapdef["C5"])


    # A six colour map. A colour wheel with Yellow, Cyan and Magenta at a
    # lightness of 90. (Magenta gets washed out with little chroma at 90), and
    # Red, Green and Blue at a lightness of 50. The Green is a bit dark and the
    # blue a bit light at 50. Overall a slightly strange colour circle but I
    # think it works quite well.
    y90 = [90 -7 90]
    m90 = [90 24 -17]
    c90 = [90 -48 -14]
    r50 = [50 78 62]
    b50 = [50 30 -81]
    g50 = [50 -54 52]
         
    push!(cmapdef, "C6" =>
       newcolourmapdef(desc = "Six colour cyclic with primaries and secondaries matched in lightness",
                       attributeStr = "cyclic",
                       hueStr = "rygcbmr",
                       colourspace = "LAB",
                       colpts = [r50
                                 y90
                                 g50
                                 c90
                                 b50
                                 m90
                                 r50],
                       splineorder = 2,
                       formula = "CIE76",
                       W = [1, 0, 0],
                       sigma = 7))                        

    push!(cmapdef, "C06" => cmapdef["C6"])

    # Zig-Zag Yellow - Magenta - Cyan - Green - Yellow.
    # Colours are well balanced over the quadrants, my new favourite.
    y90 = [90 -20 90]
    c90 = [90 -48 -14]
    m60 = [60 98 -61]
    g60 = [60 -64 61]

    push!(cmapdef, "C7" =>
          newcolourmapdef(desc="Cyclic Yellow - Magenta - Cyan - Green - Yellow",
                          attributeStr = "cyclic",
                          hueStr = "ymcgy",
                          colourspace = "LAB",
                          colpts = [y90
                                    m60
                                    c90
                                    g60
                                    y90],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    push!(cmapdef, "C07" => cmapdef["C7"])


    # Elliptical path - ok
    ang = 112

    push!(cmapdef, "C8" =>
          newcolourmapdef(desc="Cyclic map formed from an ellipse",
                          attributeStr = "cyclic",
                          hueStr = "mygbm",
                          colourspace = "LAB",
                          colpts = [70    ch2ab(42,  ang-90)
                                    90    ch2ab(82,  ang)
                                    70    ch2ab(42,  ang+90)
                                    50    ch2ab(82,  ang+180)
                                    70    ch2ab(42,  ang-90)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    push!(cmapdef, "C08" => cmapdef["C8"])

    # Elliptical path.  Greater range of lightness values and slightly
    # more saturated colours.  Seems to work however I do not find the
    # colour sequence that attractive. This is a constraint of the
    # gamut.
    ang = 124

    push!(cmapdef, "C9" =>
          newcolourmapdef(desc="Cyclic map formed from an ellipse",
                          attributeStr = "cyclic",
                          hueStr = "mybm",
                          colourspace = "LAB",
                          colpts = [60    ch2ab(36,  ang-90)
                                    95    ch2ab(90,  ang)
                                    60    ch2ab(36,  ang+90)
                                    25    ch2ab(90,  ang+180)
                                    60    ch2ab(36,  ang-90)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 7))

    push!(cmapdef, "C09" => cmapdef["C9"])
 
    # Circle at lightness 67  - sort of ok but a bit flouro
    chr = 42
    ang = 124

    push!(cmapdef, "C10" =>
          newcolourmapdef(desc="Cyclic isoluminant circle at lighhtness 67",
                          attributeStr = "cyclic-isoluminant",
                          hueStr = "mgbm",
                          colourspace = "LAB",
                          colpts = [67  ch2ab(chr,  ang-90)
                                    67  ch2ab(chr,  ang)
                                    67  ch2ab(chr,  ang+90)
                                    67  ch2ab(chr,  ang+180)
                                    67  ch2ab(chr,  ang-90)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    # Variation of C1. Perceptually this is good. Excellent balance of
    # colours in the quadrants but the colour mix is not to my taste.
    # Don't like the green.  The red-green transition clashes
    blu = [35  70 -100]

    push!(cmapdef, "C11" =>
          newcolourmapdef(desc="Cyclic blue-green-red-magenta-blue colour map",
                          attributeStr = "cyclic",
                          hueStr = "bgrmb",
                          colourspace = "LAB",
                          colpts = [blu
                                    70 -70 64
                                    35 65 50
                                    70 75 -46
                                    blu        ],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))


    #-----------------------------------------------------------------------------
    ##  Rainbow style colour maps

    #  "RAINBOW" a reasonable rainbow colour map after it has been
    # fixed by equalisecolourmap.
    push!(cmapdef, "R1" =>
          newcolourmapdef(desc = "The least worst rainbow colour map I can devise. " *
                                 "Note there are small perceptual blind spots at yellow and red",
                          attributeStr = "rainbow",
                          hueStr = "bgyrm",
                          colourspace = "LAB",
                          colpts = [35 63 -98
                                    45 -14 -30
                                    60 -55 60
                                    85 0 80
                                    55 60 62
                                    75 55 -35],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 7))

    push!(cmapdef, "RAINBOW" => cmapdef["R1"])
    push!(cmapdef, "R01" => cmapdef["R1"])

    # "RAINBOW2" Similar to R1 but with the colour map finishing at
    # red rather than continuing onto pink.
    push!(cmapdef, "R2" =>
          newcolourmapdef(desc = "Reasonable rainbow colour map from blue to red.  Note there is " *
                                 "a small perceptual blind spot at yellow",
                          attributeStr = "rainbow",
                          hueStr = "bgyr",
                          colourspace = "LAB",
                          colpts = [35 63 -98
                                    45 -14 -30
                                    60 -55 60
                                    85 0 78
                                    55 73 68],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    push!(cmapdef, "RAINBOW2" => cmapdef["R2"])
    push!(cmapdef, "R02" => cmapdef["R2"])

    # Diverging rainbow.  The blue and red points are matched in
    # lightness and chroma as are the green and magenta points
    push!(cmapdef, "R3" =>
          newcolourmapdef(desc = "Diverging-rainbow colourmap. " *
                          "Yellow is the central reference colour.  The " *
                          " blue and red end points are matched in lightness",
                          attributeStr = "diverging-rainbow",
                          hueStr = "bgymr",
                          colourspace = "LAB",
                          colpts = [45 39 -83
                                    52 -23 -23
                                    60 -55 55
                                    85 -2 85
                                    60 74 -17
                                    45 70 59],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    push!(cmapdef, "RAINBOW3" => cmapdef["R3"])
    push!(cmapdef, "R03" => cmapdef["R3"])

    # More vivid version of R2 with greater range of luminance.  Looks more
    # attractive, however I find the vivid colours tend to make you segment
    # regions in your data on the basis of colour and you can lose the overall
    # sense of structure.
    push!(cmapdef, "R4" =>
          newcolourmapdef(desc = "Vivid rainbow colour map from blue to red",
                       attributeStr = "rainbow",
                       hueStr = "bgyr",
                       colourspace = "LAB",
                       colpts = [10 42 -57
                                 20 59 -80
                                 40 55 -93
                                 50 -23 -25
                                 60 -60 60
                                 90 -12 89
                                 70 33 72
                                 55 75 65
                                 45 70 55],
                       splineorder = 2,
                       formula = "CIE76",
                       W = [1, 0, 0],
                       sigma = 5))                       

    push!(cmapdef, "R04" => cmapdef["R4"])

    #-----------------------------------------------------------------------------
    ##  Isoluminant colour maps

    push!(cmapdef, "I1" =>
          newcolourmapdef(desc = "Isoluminant blue to green to orange at lightness 70.  " *
                          "Poor on its own but works well with relief shading",
                          attributeStr = "isoluminant",
                          hueStr = "cgo",
                          colourspace = "LAB",
                          colpts = [70 ch2ab(40, -115)
                                    70 ch2ab(50, 160)
                                    70 ch2ab(50,  90)
                                    70 ch2ab(50,  45)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    push!(cmapdef, "I01" => cmapdef["I1"])

    # Adaptation of I1 shifted to 80 from 70
    push!(cmapdef, "I2" =>
          newcolourmapdef(desc = "Isoluminant blue to green to orange at lightness 80.  " *
                          "Poor on its own but works well with relief shading",
                          attributeStr = "isoluminant",
                          hueStr = "cgo",
                          colourspace = "LAB",
                          colpts = [80 ch2ab(36, -115)
                                    80 ch2ab(50, 160)
                                    80 ch2ab(50,  90)
                                    80 ch2ab(46,  55)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    push!(cmapdef, "I02" => cmapdef["I2"])

    push!(cmapdef, "I3" =>
          newcolourmapdef(desc = "Isoluminant cyan to magenta colour map",
                          attributeStr = "isoluminant",
                          hueStr = "cm",
                          colourspace = "LAB",
                          colpts = [70 ch2ab(40, -125)
                                    70 ch2ab(40, -80)
                                    70 ch2ab(40, -40)
                                    70 ch2ab(50,  0)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    push!(cmapdef, "I03" => cmapdef["I3"])

    #---------------------------------------------------------------------------
    #=
    Colour Maps for the Colour Blind
    Protanopic / Deuteranopic colour maps

    The Protanopic / Deuteranopic colour space is represented by two planes.
    One plane is defined by the neutral axis and the colour point at yellow
    575nm, and the other defined by the neutral axis and the colour point at
    blue 475nm.
    Hue angles in a,b space of the key colours common to Protanopic/Deuteranopic
    and Trichromatic viewers are:
    yellow 575nm =  1.6165 radians,  92.62 degrees
    blue   475nm = -1.3835 radians, -79.27 degrees
    =#

    # Linear/diverging map for Protanopic/Deuteranopic viewers.  The
    # symmetry requirements for diverging maps means that the colours
    # are not as saturated as one would like. However this map works
    # better than CBL2.
    push!(cmapdef, "CBL1" =>
          newcolourmapdef(desc = "Linear/diverging map for Protanopic/Deuteranopic viewers",
                          attributeStr = "linear-diverging-protanopic-deuteranopic",
                          hueStr = "kbjyw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    28 ch2ab(61, blue475)
                                    50 0 0
                                    72 ch2ab(61, yellow575)
                                    95 0 0],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # Linear map with maximal chroma for Protanopic/Deuteranopic
    # viewers.  Does not work as well as one would hope.  The colours
    # are too uneven.
    push!(cmapdef, "CBL2" =>
          newcolourmapdef(desc = "Linear map with maximal chroma for Protanopic/Deuteranopic viewers",
                          attributeStr = "linear-protanopic-deuteranopic",
                          hueStr = "kbw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    20 ch2ab(30, blue475)
                                    58 ch2ab(69, blue475)
                                    68 0 0
                                    85 ch2ab(98, yellow575)
                                    96 ch2ab(5, yellow575)
                                    98 0 0],
                          splineorder = 2;
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 9))

    # Linear map up the blue edge of the colour space
    push!(cmapdef, "CBL3" =>
          newcolourmapdef(desc = "Linear blue map for Protanopic/Deuteranopic viewers",
                          attributeStr = "linear-protanopic-deuteranopic",
                          hueStr = "kbw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    56 ch2ab(68, blue475)
                                    95 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0 ,0],
                          sigma = 9))

    # Linear map up the yellow edge of the colour space
    push!(cmapdef, "CBL4" =>
          newcolourmapdef(desc = "Linear yellow map for Protanopic/Deuteranopic viewers",
                          attributeStr = "linear-protanopic-deuteranopic",
                          hueStr = "kyw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    25 ch2ab(34, yellow575)
                                    88 ch2ab(88, yellow575)
                                    95 ch2ab(5, yellow575)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 9))

    # Diverging map blue-white-yellow.  Works well.
    push!(cmapdef, "CBD1" =>
          newcolourmapdef(desc = "Diverging map blue-white-yellow",
                          attributeStr = "diverging-protanopic-deuteranopic",
                          hueStr = "bwy",
                          colourspace = "LAB",
                          colpts = [60 ch2ab(63, blue475)
                                    95 0 0
                                    60 ch2ab(63, yellow575)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    #  Diverging-linear map blue-grey-yellow
    push!(cmapdef, "CBD2" =>
          newcolourmapdef(desc = "Diverging-linear map blue-grey-yellow",
                          attributeStr = "diverging-linear-protanopic-deuteranopic",
                          hueStr = "bjy",
                          colourspace = "LAB",
                          colpts = [57 ch2ab(67, blue475)
                                    73 0 0
                                    89 ch2ab(67, yellow575)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    # 4-phase cyclic map blue-white-yellow-black
    push!(cmapdef, "CBC1" =>
          newcolourmapdef(desc = "4-phase cyclic map blue-white-yellow-black",
                          attributeStr = "cyclic-protanopic-deuteranopic",
                          hueStr = "bwyk",
                          colourspace = "LAB",
                          colpts = [56 ch2ab(61, blue475)
                                    96 0 0
                                    56 ch2ab(61, yellow575)
                                    16 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    # 2-phase cyclic map white-yellow-white-blue
    push!(cmapdef, "CBC2" =>
          newcolourmapdef(desc = "2-phase cyclic map white-yellow-white-blue",
                          attributeStr = "cyclic-protanopic-deuteranopic",
                          hueStr = "wywb",
                          colourspace = "LAB",
                          colpts = [96 0 0
                                    55 ch2ab(68, yellow575)
                                    96 0 0
                                    55 ch2ab(68, blue475)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    ## Tritanopic colour maps
    # Hue angles in a,b space of the key colours common to Tritanopic
    # and Trichromatic viewers.
    # red  660nm  0.5648 radians,   32.36 degrees
    # cyan 485nm -2.4213 radians, -138.73 degrees

    # Tritanopic linear map with maximal chroma
    push!(cmapdef, "CBTL1" =>
          newcolourmapdef(desc = "Tritanopic linear map with maximal chroma",
                          attributeStr = "linear-tritanopic",
                          hueStr = "krjcw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    20 ch2ab(50, red660)
                                    56 ch2ab(95, red660)
                                    78 ch2ab(52, cyan485)
                                    98 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 9))

    # Tritanopic linear map, can also be used as a diverging
    # map. However the symmetry requirements of a diverging
    # map results in colours of lower chroma
    push!(cmapdef, "CBTL2" =>
          newcolourmapdef(desc = "Tritanopic linear map, can also be used as a diverging map",
                          attributeStr = "linear-diverging-tritanopic",
                          hueStr = "krjcw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    25 ch2ab(58, red660)
                                    50 0 0
                                    75 ch2ab(58, cyan485)
                                    95 0 0],
                          splineorder = 3,
                          W = [1, 0, 0],
                          formula = "CIE76",
                          sigma = 0))

    # Linear map up the blue green edge of the colour space
    push!(cmapdef, "CBTL3" =>
          newcolourmapdef(desc = "Tritanopic linear blue map",
                          attributeStr = "linear-tritanopic",
                          hueStr = "kcw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    70 ch2ab(40, cyan485)
                                    85 ch2ab(40, cyan485)
                                    95 0 0],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # Linear map up the red edge of the colour space
    push!(cmapdef, "CBTL4" =>
          newcolourmapdef(desc = "Tritanopic linear red/heat map",
                          attributeStr = "linear-tritanopic",
                          hueStr = "krw",
                          colourspace = "LAB",
                          colpts = [5 0 0
                                    45 ch2ab(100, red660)
                                    70 ch2ab(50, red660)
                                    95 0 0],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # Tritanopic diverging map
    push!(cmapdef, "CBTD1" =>
          newcolourmapdef(desc = "Tritanopic diverging map",
                          attributeStr = "diverging-tritanopic",
                          hueStr = "cwr",
                          colourspace = "LAB",
                          colpts = [75 ch2ab(39, cyan485)
                                    98 0 0
                                    75 ch2ab(39, red660)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    # 4-phase tritanopic cyclic map
    push!(cmapdef, "CBTC1" =>
          newcolourmapdef(desc = "4-phase tritanopic cyclic map",
                          attributeStr = "cyclic-tritanopic",
                          hueStr = "cwrk",
                          colourspace = "LAB",
                          colpts = [70 ch2ab(39, cyan485)
                                    100 0 0
                                    70 ch2ab(39, red660)
                                    40 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))

    # 2-phase tritanopic cyclic map
    push!(cmapdef, "CBTC2" =>
          newcolourmapdef(desc = "2-phase tritanopic cyclic map",
                          attributeStr = "cyclic-tritanopic",
                          hueStr = "wrwc",
                          colourspace = "LAB",
                          colpts = [100 0 0
                                    70 ch2ab(41, red660)
                                    100 0 0
                                    70 ch2ab(41, cyan485)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 5))



    #-----------------------------------------------------------------------------
    ##  Experimental colour maps and colour maps that illustrate some design principles

    push!(cmapdef, "X1" =>
          newcolourmapdef(desc = "Two linear segments with different slope to illustrate importance " *
                          "of lightness gradient.",
                          attributeStr = "linear-lightnessnormalised",
                          hueStr = "by",
                          colourspace = "LAB",
                          colpts = [30 ch2ab(102, -54)
                                    40  0   0
                                    90  ch2ab(90, 95)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "X2" =>
          newcolourmapdef(desc = "Two linear segments with different slope to illustrate importance " *
                          "of lightness gradient.",
                          attributeStr = "linear-CIE76normalised",
                          hueStr = "by",
                          colourspace = "LAB",
                          colpts = [30 ch2ab(102, -54)
                                    40  0   0
                                    90  ch2ab(90, 95)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    # Constant lightness 'v' path to test unimportance of having a smooth
    # path in hue/chroma.  Slight 'feature' at the red corner (Seems more
    # important on poor monitors)
    push!(cmapdef, "X3" =>
          newcolourmapdef(desc = "Isoluminant V path",
                          attributeStr = "isoluminant-HueChromaSlopeDiscontinuity",
                          hueStr = "brg",
                          colourspace = "LAB",
                          colpts = [50 17 -78
                                    50 77 57
                                    50 -48 50],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

   # A set of isoluminant colour maps only varying in saturation to test
   # the importance of saturation (not much) Colour Maps are linear with
   # a reversal to test importance of continuity.
    push!(cmapdef, "X10" =>
          newcolourmapdef(desc = "Isoluminant 50 red only varying in saturation",
                          attributeStr = "isoluminant",
                          hueStr = "r",
                          colourspace = "LAB",
                          colpts = [50 0 0
                                    50 77 64
                                    50 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    push!(cmapdef, "X11" =>
          newcolourmapdef(desc = "Isoluminant 50 blue only varying in saturation",
                          attributeStr = "isoluminant",
                          hueStr = "b",
                          colourspace = "LAB",
                          colpts = [50 0 0
                                    50 0 -56
                                    50 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    push!(cmapdef, "X12" =>
          newcolourmapdef(desc = "Isoluminant 90 green only varying in saturation",
                          attributeStr = "isoluminant",
                          hueStr = "isoluminant_90_g",
                          colourspace = "LAB",
                          colpts = [90 0 0
                                    90 -76 80
                                    90 0 0],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))


    # Difference in CIE76 and CIEDE2000 in chroma
    push!(cmapdef, "X13" =>
          newcolourmapdef(desc = "Isoluminant 55 only varying in chroma. CIEDE76",
                          attributeStr= "isoluminant-CIE76",
                          hueStr = "jr",
                          colourspace = "LAB",
                          colpts = [55 0 0
                                    55 80 67],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))

    # Same as X13 but using CIEDE2000
    push!(cmapdef, "X14" =>
          newcolourmapdef(desc = "Isoluminant 55 only varying in chroma. CIEDE2000",
                          attributeStr= "isoluminant-CIEDE2000",
                          hueStr = "jr",
                          colourspace = "LAB",
                          colpts = [55 0 0
                                    55 80 67],
                          splineorder = 2,
                          formula = "CIEDE2000",
                          W = [1, 1, 1],
                          sigma = 0))

    # Grey 0 - 100. Same as No 1 but with CIEDE2000
    push!(cmapdef, "X15" =>
          newcolourmapdef(desc = "Grey scale CIEDE2000" ,
                          attributeStr= "linear-CIEDE2000",
                          hueStr = "grey",
                          colourspace = "LAB",
                          colpts = [  0 0 0
                                      100 0 0],
                          splineorder = 2,
                          formula = "CIEDE2000",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "X16" =>
          newcolourmapdef(desc = "Isoluminant 30 only varying in chroma",
                          attributeStr= "isoluminant",
                          hueStr = "b",
                          colourspace = "LAB",
                          colpts = [30 0 0
                                    30 77 -106],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 1, 1],
                          sigma = 0))


    push!(cmapdef, "X21" =>
          newcolourmapdef(desc = "Blue to yellow section of rainbow map R1 for illustrating " *
                          "colour ordering issues",
                          attributeStr= "rainbow-section1",
                          hueStr = "bgy",
                          colourspace = "LAB",
                          colpts = [35 60 -100
                                    45 -15 -30
                                    60 -55 60
                                    85 0 80],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))


    push!(cmapdef, "X22" =>
          newcolourmapdef(desc = "Red to yellow section of rainbow map R1 for illustrating " *
                          "colour ordering issues",
                          attributeStr= "rainbow-section2",
                          hueStr = "ry",
                          colourspace = "LAB",
                          colpts = [55 70 65
                                    85 0 80],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "X23" =>
          newcolourmapdef(desc = "Red to pink section of rainbow map R1 for illustrating " *
                          "colour ordering issues",
                          attributeStr= "rainbow-section3",
                          hueStr = "rm",
                          colourspace = "LAB",
                          colpts = [55 70 65
                                    75 55 -35],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # Same as D1 but with no smoothing
    push!(cmapdef, "XD1" =>
          newcolourmapdef(desc = "Diverging blue-white-red colour map",
                          attributeStr = "diverging",
                          hueStr = "bwr",
                          colourspace = "LAB",
                          colpts = [40  ch2ab(83,-64)
                                    95  0   0
                                    40  ch2ab(83, 39)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    push!(cmapdef, "X30" =>
          newcolourmapdef(desc = "red - green - blue interpolated in rgb",
                          attributeStr = "linear",
                          hueStr = "rgb",
                          colourspace = "RGB",
                          colpts = [1.00 0.00 0.00
                                    0.00 1.00 0.00
                                    0.00 0.00 1.00],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [0, 0, 0],
                          sigma = 0))

    push!(cmapdef, "X31" =>
          newcolourmapdef(desc = "red - green - blue interpolated in CIELAB",
                          attributeStr = "linear",
                          hueStr = "rgb",
                          colourspace = "LAB",
                          colpts = [53  80   67
                                    88 -86   83
                                    32  79 -108],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [0, 0, 0],
                          sigma = 0))

   # Linear diverging blue - magenta- grey - orange - yellow.
   # Modified from 'D7' to have a double arch shaped path in an
   # attempt to improve its Metric properties.  Also starts at
   # lightness of 40 rather than 30.  The centre grey region is a bit
   # too prominant and overall the map is perhaps a bit too 'bright'
    push!(cmapdef, "XD7A" =>
          newcolourmapdef(desc = "Linear diverging blue - magenta- grey - orange - yellow.",
                          attributeStr = "diverging-linear",
                          hueStr = "bmjoy",
                          colourspace = "LAB",
                          colpts = [40 ch2ab(88, -64)
                                    55 ch2ab(70, -30)
                                    64 ch2ab(2.5, -72.5)
                                    65 0 0
                                    66 ch2ab(2.5, 107.5)
                                    75 ch2ab(70, 70)
                                    90 ch2ab(88,100)],
                          splineorder = 3,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))


    # Linear diverging green - grey - yellow Reasonable, perhaps
    # easier on the eye than D7
    rad = 65

    push!(cmapdef, "XD7C" =>
          newcolourmapdef(desc = "Diverging green - grey - yellow",
                          attributeStr = "diverging-linear",
                          hueStr = "gjy",
                          colourspace = "LAB",
                          colpts = [40 ch2ab(rad, 136)
                                    65 0 0
                                    90 ch2ab(rad, 95)],
                          splineorder = 2,
                          formula = "CIE76",
                          W = [1, 0, 0],
                          sigma = 0))

    # -------- End of dictionary construction ---------------------

    CM = newcolourmapdef()  # Create a colour map definition in main scope

    try
        CM = cmapdef[uppercase(I)]
    catch
        catalogue(cmapdef, I)
        return
    end

    ##-------------------------------------------------------------

    # Adjust chroma/saturation but only if colourspace is LAB
    if uppercase(CM.colourspace) == "LAB"
        CM.colpts[:,2:3] = chromaK * CM.colpts[:,2:3]
    end

    # Colour map path is formed via a b-spline in the specified colour space
    Npts = size(CM.colpts,1)

    if Npts < 2
        println(I)
        error("Number of input points must be 2 or more")
    elseif Npts < CM.splineorder
        error("Spline order is greater than number of data points")
    end

    # Rely on the attribute string to identify if colour map is cyclic.  We may
    # want to construct a colour map that has identical endpoints but do not
    # necessarily want continuity in the slope of the colour map path.
    if occursin("cyclic", lowercase(CM.attributeStr))
        cyclic = true
        labspline = pbspline(CM.colpts', CM.splineorder, N)
    else
        cyclic = false
        labspline = bbspline(CM.colpts', CM.splineorder, N)
    end

    # Apply contrast equalisation with required parameters. Note that sigma is
    # normalised with respect to a colour map of length 256 so that if a short
    # colour map is specified the smoothing that is applied is adjusted to suit.
    CM.sigma = CM.sigma*N/256

    map = equalisecolourmap(CM.colourspace, labspline', CM.formula,
                            CM.W, CM.sigma, cyclic, diagnostics)

    # If specified apply a cyclic shift to the colour map
    if shift != 0
        if !occursin("cyclic", lowercase(CM.attributeStr))
            @warn "Colour map shifting being applied to a non-cyclic map"
        end
        map = circshift(map, round(Int, N*shift))
    end

    if reverse
       map = Base.reverse(map, dims=1)
    end

    # Compute mean chroma of colour map for use in the name construction
    lab = srgb2lab(map)
    meanchroma = sum(sqrt.(sum(lab[:,2:3].^2, dims=2)))/N

    # Construct lightness range description
    if uppercase(CM.colourspace) == "LAB"  # Use the control points
        L = CM.colpts[:,1]
    else  # For RGB use the converted CIELAB values
        L = round.(lab[:,1])
    end
    minL = minimum(L)
    maxL = maximum(L)

    if minL == maxL     # Isoluminant
        LStr = @sprintf("%d", minL)

    elseif L[1] == maxL &&
                   (occursin("diverging", lowercase(CM.attributeStr)) ||
                    occursin("linear", lowercase(CM.attributeStr)))
        LStr = @sprintf("%d-%d", maxL, minL)
    else
        LStr = @sprintf("%d-%d", minL, maxL)
    end

    # Build overall colour map name
    name = @sprintf("%s_%s_%s_c%d_n%d",
       CM.attributeStr, CM.hueStr, LStr, Int(round(meanchroma)), N)

    if shift != 0
       name = @sprintf("%s_s%d", name, round(Int, shift*100))
    end

    if reverse
        name = @sprintf("%s_r", name)
    end

#=
    if diagnostics  # Print description and plot path in colourspace
        fprintf('%s\n',desc)
        colourmappath(map, 'fig', 10)
    end
=#

    # Build an array of ColorTypes.RGB values to return
    rgbmap = Array{ColorTypes.RGBA{Float64}}(undef, N)
    for i = 1:N
        rgbmap[i] = ColorTypes.RGBA(map[i,1], map[i,2], map[i,3], 1.0)
    end

    if returnname
        return rgbmap, name, CM.desc
    else
        return rgbmap
    end
end

#------------------------------------------------------------------
# Conversion from (chroma, hue angle degrees) description to (a*, b*) coords.
# Note we return a 1 x 2 matrix

function ch2ab(chroma, angle_degrees)
    theta = angle_degrees/180*pi
    return ab = chroma*[cos(theta) sin(theta)]
end

#------------------------------------------------------------------
#
# Function to list colour maps with names containing a specific string.
# Typically this is used to search for colour maps having a specified attribute:
# 'linear', 'diverging', 'rainbow', 'cyclic', 'isoluminant' or 'all'.

# To determine the full name of a colour map it has to be constructed.
# As this function constructs all colour maps this makes it handy for
# testing

# Formatting of long description strings needs improving.

function catalogue(cmapdef, str="ALL")

    str = uppercase(str)

    # Check each colour name for the specified search string.  Exclude the
    # experimental maps with key/label starting with X.
    @printf("\nCMAP label       Colour Map name\n")
    @printf("--------------------------------------------\n")

    found = false

    for label in sort(collect(keys(cmapdef)))
        map, name, desc = cmap(label, returnname=true)

        if label[1] != 'X'   # do not list experimental maps
            if findfirst(str, uppercase(name)) !== nothing || str == "ALL"
                @printf("%-10s  %s\n            ( %s )\n", label, desc, name)
                found = true
            end
        end
    end

    if !found
        @printf("Sorry, no colour map with label or attribute %s found\n", str)
    end

    return
end

#-------------------------------------------------------------------------------
"""
equalisecolourmap/equalizecolormap - Equalise colour contrast over a colour map

This function is used by cmap() and you would not normally call this
function directly. However, you may want to try using this function to
equalise the perceptual contrast of colour maps obtained from some
other source.

```
Usage: newrgbmap = equalisecolourmap(rgblab, map, formula, W, sigma, diagnostics)
                   equalizecolormap(....

Arguments:     rgblab - String "RGB" or "LAB" indicating the type of data
                        in map.
                  map - A Nx3 RGB or CIELAB colour map
                        or an array of ColorTypes.RGBA{Float64} values
              formula - String "CIE76" or "CIEDE2000"
                    W - A 3-vector of weights to be applied to the
                        lightness, chroma and hue components of the
                        difference equation. It is recommended that you
                        use [1, 0, 0] to only take into account lightness.
                        If desired use  [1, 1, 1] for the full formula.
                        See note below.
                sigma - Optional Gaussian smoothing parameter, see
                        explanation below.
               cyclic - Boolean flag indicating whether the colour map is
                        cyclic. This affects how smoothing is applied at
                        the end points.
          diagnostics - Optional boolean flag indicating whether diagnostic
                        plots should be displayed.  Defaults to false.

Returns:    newrgbmap - RGB colour map adjusted so that the perceptual
                        contrast of colours along the colour map is constant.
                        This is a Nx3 Array of Float64 values.
```
Suggested parameters:

The CIE76 and CIEDE2000 colour difference formulas were developed for
much lower spatial frequencies than we are typically interested in.
Neither is ideal for our application.  The main thing to note is that
at *fine* spatial frequencies perceptual contrast is dominated by
*lightness* difference, chroma and hue are relatively unimportant.

For colour maps with a significant range of lightness use:

```
                       formula = "CIE76" or "CIEDE2000"
                             W = [1, 0, 0]  (Only correct for lightness)
                         sigma = 5 - 7
```
For isoluminant or low lightness gradient colour maps use:

```
                       formula = "CIE76"
                             W = [1, 1, 1]  (Correct for colour and lightness)
                         sigma = 5 - 7
```
Ideally, for a colour map to be effective the perceptual contrast along the
colour map should be constant.  Many colour maps are very poor in this regard.
Try testing your favourite colour map on the sineramp() test image.  The
perceptual contrast is very much dominated by the contrast in colour lightness
values along the map.  This function attempts to equalise the chosen
perceptual contrast measure along a colour map by stretching and/or
compressing sections of the colour map.

This function's primary use is for the correction of colour maps generated by
cmap() however it can be applied to any colour map.  There are limitations to
what this function can correct.  When applied to some of MATLAB's colour maps
such as 'jet', 'hsv' and 'cool' you get colour discontinuity artifacts because
these colour maps have segments that are nearly constant in lightness.
However, it does a nice job of fixing up MATLAB's 'hot', 'winter', 'spring'
and 'autumn' colour maps.  If you do see colour discontinuities in the
resulting colour map try changing W from [1, 0, 0] to [1, 1, 1], or some
intermediate weighting of [1, 0.5, 0.5], say.

Difference formula: Neither CIE76 or CIEDE2000 difference measures are ideal
for the high spatial frequencies that we are interested in.  Empirically I
find that CIEDE2000 seems to give slightly better results on colour maps where
there is a significant lightness gradient (this applies to most colour maps).
In this case you would be using a weighting vector W = [1, 0, 0].  For
isoluminant, or low lightness gradient colour maps where one is using a
weighting vector W = [1, 1, 1] CIE76 should be used as the CIEDE2000 chroma
correction is inapropriate for the spatial frequencies we are interested in.

Weighting vetor W: The CIEDE2000 colour difference formula incorporates the
scaling parameters kL, kC, kH in the demonimator of the lightness, chroma, and
hue difference components respectively.  The 3 components of W correspond to
the reciprocal of these 3 parameters.  (I do not know why they chose to put
kL, kC, kH in the denominator. If you wanted to ignore, say, the chroma
component you would have to set kC to Inf, rather than setting W[2] to 0 which
seems more sensible to me).  If you are using CIE76 then W[2] amd W[3] are
applied to the differences in a and b.  In this case you should ensure W[2] =
W[3].  In general, for the spatial frequencies of interest to us, lightness
differences are overwhelmingly more important than chroma or hue and W shoud
be set to [1, 0, 0]

Smoothing parameter sigma:
The output colour map will have lightness values of constant slope magnitude.
However, it is possible that the sign of the slope may change, for example at
the mid point of a bilateral colour map.  This slope discontinuity of lightness
can induce a false apparent feature in the colour map.  A smaller effect is
also occurs for slope discontinuities in a and b.  For such colour maps it can
be useful to introduce a small amount of smoothing of the Lab values to soften
the transition of sign in the slope to remove this apparent feature.  However
in doing this one creates a small region of suppressed luminance contrast in
the colour map which induces a 'blind spot' that compromises the visibility of
features should they fall in that data range.  Accordingly the smoothing
should be kept to a minimum.  A value of sigma in the range 5 to 7 in a 256
element colour map seems about right.  As a guideline sigma should not be more
than about 1/25 of the number of entries in the colour map, preferably less.

Reference: Peter Kovesi. Good Colour Maps: How to Design
Them. [arXiv:1509.03700 [cs.GR] 2015](https://arXiv:1509.03700)

See also: cmap, applycycliccolourmap, applydivergingcolourmap,
sineramp, circlesineramp
"""
function equalisecolourmap(rgblab::AbstractString, cmap::AbstractMatrix{Float64},
                           formula::AbstractString="CIE76", W::Array=[1.0, 0.0, 0.0],
                           sigma::Real = 0.0, cyclic::Bool = false, diagnostics::Bool = false)
   # October  2015  - Ported from MATLAB to Julia

    N = size(cmap,1)   # No of colour map entries

    if N/sigma < 25
        @warn "It is not recommended that sigma be larger than 1/25 of the colour map length"
    end

    rgblab = uppercase(rgblab)
    formula = uppercase(formula)

    if rgblab == "RGB" && (maximum(cmap) > 1.01 || minimum(cmap) < -0.01)
        error("If map is RGB values should be in the range 0-1")
    elseif rgblab == "LAB" && maximum(abs.(cmap)) < 10
        error("If map is LAB magnitude of values are expected to be > 10")
    end

    # If input is RGB convert colour map to Lab. Also, ensure that we
    # have both RGB and Lab representations of the colour map.  I am
    # assuming that the Colors.convert() function uses a default white
    # point of D65
    if rgblab == "RGB"
        rgbmap = copy(cmap)
        labmap = srgb2lab(cmap)
        L = labmap[:,1]
        a = labmap[:,2]
        b = labmap[:,3]
    elseif rgblab == "LAB"
        labmap = copy(cmap)
        rgbmap = lab2srgb(cmap)
        L = cmap[:,1]
        a = cmap[:,2]
        b = cmap[:,3]
    else
        error("Input must be RGB or LAB")
    end

    # The following section of code computes the locations to interpolate into
    # the colour map in order to achieve equal steps of perceptual contrast.
    # The process is repeated recursively on its own output. This helps overcome
    # the approximations induced by using linear interpolation to estimate the
    # locations of equal perceptual contrast. This is mainly an issue for
    # colour maps with only a few entries.

    initialdeltaE = 0  # Define these variables in main scope
    initialcumdE = 0
    initialequicumdE = 0
    initialnewN = 0

    for iter = 1:3
        # Compute perceptual colour difference values along the colour map using
        # the chosen formula and weighting vector.
        if formula ==  "CIE76"
            deltaE = cie76(L, a, b, W)
        elseif formula == "CIEDE2000"
            deltaE = ciede2000(L, a, b, W)
        else
            error("Unknown colour difference formula")
        end

        # Form cumulative sum of of delta E values.  However, first ensure all
        # values are larger than 0.001 to ensure the cumulative sum always
        # increases.
        deltaE[deltaE .< 0.001] .= 0.001
        cumdE = cumsum(deltaE, dims=1)

        # Form an array of equal steps in cumulative contrast change.
        equicumdE =  collect(0:(N-1))./(N-1) .* (cumdE[end]-cumdE[1]) .+ cumdE[1]

        # Solve for the locations that would give equal Delta E values.
        newN = interp1(cumdE, 1:N, equicumdE)

        # newN now represents the locations where we want to interpolate into the
        # colour map to obtain constant perceptual contrast
        Li = interpolate(L, BSpline(Linear()))
        L = [Li(v) for v in newN]

        ai = interpolate(a, BSpline(Linear()))
        a = [ai(v) for v in newN]

        bi = interpolate(b, BSpline(Linear()))
        b = [bi(v) for v in newN]

        # Record initial colour differences for evaluation at the end
        if iter == 1
            initialdeltaE = deltaE
            initialcumdE = cumdE
            initialequicumdE = equicumdE
            initialnewN = newN
        end
    end

    # Apply smoothing of the path in CIELAB space if requested.  The aim is to
    # smooth out sharp lightness/colour changes that might induce the perception
    # of false features.  In doing this there will be some cost to the
    # perceptual contrast at these points.
    if sigma > 0.0
        L = smooth(L, sigma, cyclic)
        a = smooth(a, sigma, cyclic)
        b = smooth(b, sigma, cyclic)
    end

    # Convert map back to RGB
    newlabmap = [L a b]
    newrgbmap = lab2srgb(newlabmap)

    if diagnostics

        # Compute actual perceptual contrast values achieved
        if formula == "CIE76"
            newdeltaE = cie76(L, a, b, W)
        elseif formula == "CIEDE2000"
            newdeltaE = ciede2000(L, a, b, W)
        else
            error("Unknown colour difference formula")
        end

        sr = sineramp()

        PyPlot.figure(1); PyPlot.clf()
        PyPlot.subplot(2,1,1)
        PyPlot.imshow(applycolourmap(sr, rgbmap))    # Unequalised colour map
        PyPlot.axis("off");  PyPlot.axis("tight")
        PyPlot.title("Unequalised colour map")

        PyPlot.subplot(2,1,2)
        PyPlot.imshow(applycolourmap(sr, newrgbmap)) # Equalised colour map
        PyPlot.axis("off");  PyPlot.axis("tight")
        PyPlot.title("Equalised colour map")

        PyPlot.figure(2); PyPlot.clf()
        PyPlot.subplot(2,1,1)
        PyPlot.plot(collect(1:N), initialcumdE)
        PyPlot.axis([1, N, 0, 1.05*maximum(initialcumdE)])
        PyPlot.xlabel("Colour map index")
        PyPlot.title(@sprintf("Cumulative change in %s with weights [%.1f  %.1f  %.1f] of input colour map",
                   formula, W[1], W[2], W[3]))

        PyPlot.subplot(2,1,2)
        PyPlot.plot(1:N, initialdeltaE, 1:N, newdeltaE)
        PyPlot.axis([1, N, 0, 1.05*maximum(initialdeltaE)])
        PyPlot.legend(["Original colour map",
               "Adjusted colour map"], "upper left");
        PyPlot.title(@sprintf("Magnitude of raw and corrected %s differences along colour map", formula))
        PyPlot.xlabel("Colour map index")
        PyPlot.ylabel("dE")

        # Convert newmap back to Lab to check for gamut clipping
        labmap = srgb2lab(newrgbmap)
        PyPlot.figure(3); PyPlot.clf()
        PyPlot.subplot(3,1,3)
        PyPlot.plot(1:N, L-labmap[:,1],
             1:N, a-labmap[:,2],
             1:N, b-labmap[:,3])
        PyPlot.legend(["Lightness", "a", "b"], "upper left")
        maxe = maximum(abs.([L-labmap[:,1]; a-labmap[:,2]; b-labmap[:,3]]))
        PyPlot.axis([1, N, -maxe, maxe])
        PyPlot.title("Difference between desired and achieved L a b values (gamut clipping)")

        # Plot RGB values
        PyPlot.subplot(3,1,1)
        PyPlot.plot(1:N, newrgbmap[:,1],"r-",
             1:N, newrgbmap[:,2],"g-",
             1:N, newrgbmap[:,3],"b-")

        PyPlot.legend(["Red", "Green", "Blue"], "upper left")
        PyPlot.axis([1, N, 0, 1.1])
        PyPlot.title("RGB values along colour map")

        # Plot Lab values
        PyPlot.subplot(3,1,2)
        PyPlot.plot(1:N, L, 1:N, a, 1:N, b)
        PyPlot.legend(["Lightness", "a", "b"], "upper left")
        PyPlot.axis([1, N, -100, 100])
        PyPlot.title("L a b values along colour map")

    end  # of diagnostics

    return newrgbmap
end


# Case when colour map is an array of ColorTypes.RGB{Float64}

function equalisecolourmap(rgblab::AbstractString, cmap::AbstractVector{ColorTypes.RGB{Float64}},
                           formula::AbstractString="CIE76", W::Array=[1.0, 0.0, 0.0],
                           sigma::Real = 0.0, cyclic::Bool = false, diagnostics::Bool = false)

    return equalisecolourmap(rgblab, RGB2FloatArray(cmap), formula, W,
                             sigma, cyclic, diagnostics)
end


# Case when colour map is an array of ColorTypes.RGBA{Float64}

function equalisecolourmap(rgblab::AbstractString, cmap::AbstractVector{ColorTypes.RGBA{Float64}},
                           formula::AbstractString="CIE76", W::Array=[1.0, 0.0, 0.0],
                           sigma::Real = 0.0, cyclic::Bool = false, diagnostics::Bool = false)

    return equalisecolourmap(rgblab, RGBA2FloatArray(cmap), formula, W,
                             sigma, cyclic, diagnostics)
end


# Convenience functions for those who spell colour without a 'u' and equalise with a 'z' ...
"""
equalisecolourmap - Equalise colour contrast over a colourmap
equalizecolormap
```
Usage: newrgbmap = equalisecolourmap(rgblab, map, formula, W, sigma, diagnostics)
                   equalizecolormap(....

Arguments:     rgblab - String "RGB" or "LAB" indicating the type of data
                        in map.
                  map - A Nx3 RGB or CIELAB colour map
                        or an array of ColorTypes.RGB{Float64} values
              formula - String "CIE76" or "CIEDE2000"
                    W - A 3-vector of weights to be applied to the
                        lightness, chroma and hue components of the
                        difference equation. It is recommended that you
                        use [1, 0, 0] to only take into account lightness.
                        If desired used  [1, 1, 1] for the full formula.
                sigma - Optional Gaussian smoothing parameter.
               cyclic - Boolean flag indicating whether the colour map is
                        cyclic. This affects how smoothing is applied at
                        the end points.
          diagnostics - Optional boolean flag indicating whether diagnostic
                        plots should be displayed.  Defaults to false.

Returns:    newrgbmap - RGB colour map adjusted so that the perceptual
                        contrast of colours along the colour map is constant.
                        This is a Nx3 Array of Float64 values.

For full documentation see equalisecolourmap()
                                 ^     ^
```
See also: cmap, sineramp, circlesineramp
"""
function equalizecolormap(rgblab::AbstractString, cmap::Array{Float64,2},
                           formula::AbstractString="CIE76", W::Array=[1.0, 0.0, 0.0],
                           sigma::Real = 0.0, cyclic::Bool = false, diagnostics::Bool = false)

    return equalisecolourmap(rgblab, cmap, formula, W, sigma, cyclic, diagnostics)
end

# Case when colour map is an array of ColorTypes.RGB{Float64}

function equalizecolormap(rgblab::AbstractString, cmap::Array{ColorTypes.RGB{Float64},1},
                           formula::AbstractString="CIE76", W::Array=[1.0, 0.0, 0.0],
                           sigma::Real = 0.0, cyclic::Bool = false, diagnostics::Bool = false)

    return equalisecolourmap(rgblab, RGB2FloatArray(cmap), formula, W,
                             sigma, cyclic, diagnostics)
end


# Case when colour map is an array of ColorTypes.RGBA{Float64}

function equalizecolormap(rgblab::AbstractString, cmap::Array{ColorTypes.RGBA{Float64},1},
                           formula::AbstractString="CIE76", W::Array=[1.0, 0.0, 0.0],
                           sigma::Real = 0.0, cyclic::Bool = false, diagnostics::Bool = false)

    return equalisecolourmap(rgblab, RGBA2FloatArray(cmap), formula, W,
                             sigma, cyclic, diagnostics)
end


#----------------------------------------------------------------------------
#
# Function to smooth an array of values but also ensure end values are
# not altered or, if the map is cyclic, ensures smoothing is applied
# across the end points in a cyclic manner.  It is assumed that the
# input data is a column vector.

function smooth(L::Array{T,1}, sigma::Real, cyclic::Bool) where {T<:Real}

    if cyclic
        Le = [L; L; L] # Form a concatenation of 3 repetitions of the array.

        Ls = gaussfilt1d(Le, sigma)               # Apply smoothing filter
        Ls = Ls[length(L)+1: length(L)+length(L)] # and then return the center section

    else  # Non-cyclic colour map: Pad out input array L at both ends by 3*sigma
          # with additional values at the same slope.  The aim is to eliminate
          # edge effects in the filtering
        extension = collect(1:ceil(3*sigma))

        dL1 = L[2]-L[1]
        dL2 = L[end]-L[end-1]
        Le = [-reverse(dL1*extension,dims=1).+L[1]; L;  dL2*extension.+L[end]]

        Ls = gaussfilt1d(Le, sigma) # Apply smoothing filter

        # Trim off extensions
        Ls = Ls[length(extension)+1 : length(extension)+length(L)]
    end

    return Ls
end

#----------------------------------------------------------------------------
"""
deltaE: Compute weighted Delta E between successive entries in a
colour map using the CIE76 formula + weighting
```
Usage: deltaE = cie76(L::Array, a::Array, b::Array, W::Array)
```
"""
function cie76(L::Array, a::Array, b::Array, W::Array)

    N = length(L)

    # Compute central differences
    dL = zeros(size(L))
    da = zeros(size(a))
    db = zeros(size(b))

    dL[2:end-1] = (L[3:end] - L[1:end-2])/2
    da[2:end-1] = (a[3:end] - a[1:end-2])/2
    db[2:end-1] = (b[3:end] - b[1:end-2])/2

    # Differences at end points
    dL[1] = L[2] - L[1];  dL[end] = L[end] - L[end-1]
    da[1] = a[2] - a[1];  da[end] = a[end] - a[end-1]
    db[1] = b[2] - b[1];  db[end] = b[end] - b[end-1]

    return deltaE = sqrt.(W[1]*dL.^2 + W[2]*da.^2 + W[3]*db.^2)
end

#----------------------------------------------------------------------------
"""
ciede2000: Compute weighted Delta E between successive entries in a
colour map using the CIEDE2000 formula + weighting
```
Usage: deltaE = ciede2000(L::Array, a::Array, b::Array, W::Array)
```
"""
function ciede2000(L::Array, a::Array, b::Array, W::Array)

    N = length(L)
    deltaE = zeros(N, 1)
    kl = 1/W[1]
    kc = 1/W[2]
    kh = 1/W[3]

    # Compute deltaE using central differences
    for i = 2:N-1
        deltaE[i] = Colors.colordiff(Colors.Lab(L[i+1],a[i+1],b[i+1]), Colors.Lab(L[i-1],a[i-1],b[i-1]);
                                     metric=Colors.DE_2000(kl,kc,kh))/2
    end

    # Differences at end points
    deltaE[1] = Colors.colordiff(Colors.Lab(L[2],a[2],b[2]), Colors.Lab(L[1],a[1],b[1]);
                                 metric = Colors.DE_2000(kl,kc,kh))
    deltaE[N] = Colors.colordiff(Colors.Lab(L[N],a[N],b[N]), Colors.Lab(L[N-1],a[N-1],b[N-1]);
                                 metric=Colors.DE_2000(kl,kc,kh))

    return deltaE
end


#----------------------------------------------------------------------------
"""
Convenience function for converting an Nx3 array of RGB values in a
colour map to an Nx3 array of CIELAB values.  Function can also be
used to convert a 3 channel RGB image to a 3 channel CIELAB image

Note it appears that the Colors.convert() function uses a default white
point of D65

```
 Usage:  lab = srgb2lab(rgb)

 Argument:    rgb - A N x 3 array of RGB values or a 3 channel RGB image.
 Returns:     lab - A N x 3 array of Lab values of a 3 channel CIELAB image.

```
See also: lab2srgb
"""
function srgb2lab(rgb::AbstractMatrix{T}) where {T}

    N = size(rgb,1)
    lab = zeros(N,3)

    for i = 1:N
        labval = Colors.convert(ColorTypes.Lab, ColorTypes.RGB(rgb[i,1], rgb[i,2], rgb[i,3]))
        lab[i,1] = labval.l
        lab[i,2] = labval.a
        lab[i,3] = labval.b
    end

    return lab
end

#----------------------------------------------------------------------------
#
# Convenience function for converting a 3 channel RGB image to a 3
# channel CIELAB image
#
# Usage:  lab = srgb2lab(rgb)

function srgb2lab(rgb::Array{T,3}) where {T}

    (rows, cols, chan) = size(rgb)
    lab = zeros(size(rgb))

    for r = 1:rows, c = 1:cols
        labval = Colors.convert(ColorTypes.Lab, ColorTypes.RGB(rgb[r,c,1], rgb[r,c,2], rgb[r,c,3]))
        lab[r,c,1] = labval.l
        lab[r,c,2] = labval.a
        lab[r,c,3] = labval.b
    end

    return lab
end

#----------------------------------------------------------------------------
"""
Convenience function for converting an Nx3 array of CIELAB values in a
colour map to an Nx3 array of RGB values.  Function can also be
used to convert a 3 channel CIELAB image to a 3 channel RGB image

Note it appears that the Colors.convert() function uses a default white
point of D65

```
 Usage:  rgb = srgb2lab(lab)

 Argument:   lab - A N x 3 array of CIELAB values of a 3 channel CIELAB image.
 Returns:    rgb - A N x 3 array of RGB values or a 3 channel RGB image.
```
See also: srgb2lab
"""
function lab2srgb(lab::AbstractMatrix{T}) where {T}

    N = size(lab,1)
    rgb = zeros(N,3)

    for i = 1:N
        rgbval = Colors.convert(ColorTypes.RGB, ColorTypes.Lab(lab[i,1], lab[i,2], lab[i,3]))
        rgb[i,1] = rgbval.r
        rgb[i,2] = rgbval.g
        rgb[i,3] = rgbval.b
    end

    return rgb
end

#----------------------------------------------------------------------------
#
# Convenience function for converting a 3 channel Lab image to a 3
# channel RGB image
#
# Usage:  rgb = lab2srgb(lab)

function lab2srgb(lab::Array{T,3}) where {T}

    (rows, cols, chan) = size(lab)
    rgb = zeros(size(lab))

    for r = 1:rows, c = 1:cols
        rgbval = Colors.convert(ColorTypes.RGB, ColorTypes.Lab(lab[r,c,1], lab[r,c,2], lab[r,c,3]))
        rgb[r,c,1] = rgbval.r
        rgb[r,c,2] = rgbval.g
        rgb[r,c,3] = rgbval.b
    end

    return rgb
end

#----------------------------------------------------------------------------
"""
Convert an array of ColorTypes RGB values to an array of UInt32 values
for use as a colour map in Winston
```
 Usage:  uint32rgb = RGBA2UInt32(rgbmap)

 Argument:   rgbmap - Vector of ColorTypes.RGBA values as
                      returned by cmap().

 Returns: uint32rgb - An array of UInt32 values packed with the 8 bit RGB values.
```
See also: cmap
"""
function RGBA2UInt32(rgb::Vector{ColorTypes.RGBA{Float64}})

    N = length(rgb)
    uint32rgb = zeros(UInt32, N)

    for i = 1:N
        r = round(UInt32, rgb[i].r*255)
        g = round(UInt32, rgb[i].g*255)
        b = round(UInt32, rgb[i].b*255)
        uint32rgb[i] = r << 16 + g << 8 + b
    end

    return uint32rgb
end

#----------------------------------------------------------------------------
"""
linearrgbmap: Linear rgb colourmap from black to a specified colour

```
Usage: cmap = linearrgbmap(C, N)

Arguments:  C - 3-vector specifying RGB colour
            N - Number of colourmap elements, defaults to 256

Returns: cmap - N element ColorTypes.RGBA colourmap ranging from [0 0 0]
                to RGB colour C
```
It is suggested that you pass the resulting colour map to equalisecolourmap()
to obtain a map with uniform steps in perceptual lightness

```
> cmap = equalisecolourmap("rgb", linearrgbmap(C, N))
```
See also: equalisecolourmap, ternarymaps
"""
function linearrgbmap(C::Array, N::Int = 256)

    @assert length(C) == 3 "Colour must be a 3 element array"

    rgbmap = zeros(N,3)
    ramp = (0:(N-1))/(N-1)

    for n = 1:3
        rgbmap[:,n] = C[n] * ramp
    end

    return FloatArray2RGBA(rgbmap)
end

#-------------------------------------------------------------------
# Convert Nx3 Float64 array to  N array of ColorTypes.RGB{Float64}

function FloatArray2RGB(cmap::Array{Float64,2})

    (N,cols) = size(cmap)
    @assert cols == 3  "Color map data must be N x 3"

    rgbmap = Array{ColorTypes.RGB{Float64}}(N)
    for i = 1:N
        rgbmap[i] = ColorTypes.RGB(cmap[i,1], cmap[i,2], cmap[i,3])
    end

    return rgbmap
end

#-------------------------------------------------------------------
# Convert Nx3 Float64 array to  N array of ColorTypes.RGBA{Float64}

function FloatArray2RGBA(cmap::Array{Float64,2})

    (N,cols) = size(cmap)
    @assert cols == 3  "Color map data must be N x 3"

    rgbmap = Array{ColorTypes.RGBA{Float64}}(undef, N)
    for i = 1:N
        rgbmap[i] = ColorTypes.RGBA(cmap[i,1], cmap[i,2], cmap[i,3],1.0)
    end

    return rgbmap
end


#-------------------------------------------------------------------
# Convert N array of ColorTypes.RGB{Float64} to Nx3 Float64 array

function RGB2FloatArray(rgbmap::Array{ColorTypes.RGB{Float64},1})

    N = length(rgbmap)

    cmap = Array{Float64}(undef,N,3)
    for i = 1:N
        cmap[i,:] = [rgbmap[i].r rgbmap[i].g rgbmap[i].b]
    end

    return cmap
end

#-------------------------------------------------------------------------

# Convert N array of ColorTypes.RGBA{Float64} to Nx3 Float64 array

function RGBA2FloatArray(rgbmap::Array{ColorTypes.RGBA{Float64},1})

    N = length(rgbmap)

    cmap = Array{Float64}(undef,N,3)
    for i = 1:N
        cmap[i,:] = [rgbmap[i].r rgbmap[i].g rgbmap[i].b]
    end

    return cmap
end

#-------------------------------------------------------------------
