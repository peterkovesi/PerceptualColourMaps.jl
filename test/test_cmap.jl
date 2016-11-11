# Test cmap.jl

# Tests could be more comprehensive (of course).  In some cases all
# that is done is to execute the function in some way just to make
# sure no exceptions are thrown as a result of something breaking with
# a new version of Julia.

println("testing cmap")

# cmap: Test cmap by calling it with no arguments. This generates a
# list of all the colour maps and in the process generates them all.
cmap() 

#=  See if this is what causes Travis to fail...
# equalisecolourmap: Generate a colour map in Lab space with an uneven
# ramp in lightness and check that this is corrected
rgblab = "LAB"
labmap = zeros(256,3)
labmap[1:127,1] = linspace(0,20,127)
labmap[128:256,1] = linspace(20,100,129)
formula = "CIE76"
W = [1,0,0]
sigma = 1
rgbmap = equalisecolourmap(rgblab, labmap, formula, W, sigma)
# Convert to Nx3 array and then back to lab space. Then check that dL
# is roughly constant
labmap2 = srgb2lab(rgbmap)
dL = gradient(labmap2[:,1])
@test maximum(dL[2:end-1]) - minimum(dL[2:end-1]) < 1e-1
=#

# linearrgbmap
rgbmap = linearrgbmap([1,1,1],99)
rgbmap2 = PerceptualColourMaps.convert(Array{Float64,2},rgbmap)
# check middle colour is [.5 .5 .5]
@test maximum(abs(rgbmap2[50:50,:] - [0.5 0.5 0.5])) < 1e-6


# UInt32colormap
ui32 = UInt32colormap(cmap("L3"))

# srgb2lab and lab2srgb
rgb = [1 0 0
       0 1 0
       0 0 1]

# lab values of rgb values above
lab = [ 53.2377   80.1029   67.2144
        87.7346  -86.1606   83.1862
        32.2966   79.2009 -107.8615]

clab = srgb2lab(rgb)
crgb = lab2srgb(clab)
@test maximum(abs(rgb-crgb)) < 1e-1
@test maximum(abs(lab-clab)) < 1e-1

