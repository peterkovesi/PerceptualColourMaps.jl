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

Reference:
[Good Colour Maps: How to Design Them.  arXiv:1509.03700 [cs.GR] 2015.](http://arxiv.org/abs/1509.03700)

"""
module PerceptualColourMaps

include("cmap.jl")
include("applycolourmaps.jl")
include("viewlabspace.jl")
include("utilities.jl")

end  # module

