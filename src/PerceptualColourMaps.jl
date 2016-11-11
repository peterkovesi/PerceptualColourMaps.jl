#=----------------------------------------------------------------------------

Perceptually Uniform Colour Maps

Copyright (c) 2015 Peter Kovesi
pk@peterkovesi.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

The Software is provided "as is", without warranty of any kind.

PK October 2015


----------------------------------------------------------------------------=#
"""
**PerceptualColourMaps**

Perceptually Uniform Colour maps

Peter Kovesi  

[peterkovesi.com](http://peterkovesi.com)


*Colour Map Generation and Application*

* cmap - Library of perceptually uniform colour maps.
* equalisecolourmap - Equalise colour contrast over a colour map.
* linearrgbmap - Linear rgb colourmap from black to a specified colour.
* applycolourmap - Applies colourmap to a single channel image to obtain an RGB result.
* applycycliccolourmap - Applies a cyclic colour map to an image of angular data.
* applydivergingcolourmap - Applies a diverging colour map to an image.
* ternaryimage - Perceptualy uniform ternary image from 3 bands of data.
* relief - Generates a relief shaded image.
* viewlabspace - Visualisation of Lab colour space.

*Images for testing colour maps*

* sineramp - Generates sine on a ramp colour map test image.
* circlesineramp - Generates a test image for evaluating cyclic colour maps.

*Utilities*

* histtruncate - Truncates ends of an image histogram.
* normalise - Normalises image values to 0-1, or to desired mean and variance.
* srgb2lab - Convert RGB colour map or RGB image to Lab.
* lab2srgb - Convert Lab colour map or Lab image to RGB.



*Reference:*

[Good Colour Maps: How to Design Them.  arXiv:1509.03700 [cs.GR] 2015.](http://arxiv.org/abs/1509.03700)

"""
module PerceptualColourMaps

using Compat
import Compat.ASCIIString

include("cmap.jl")
include("applycolourmaps.jl")
include("viewlabspace.jl")
include("relief.jl")
include("utilities.jl")

end  # module

