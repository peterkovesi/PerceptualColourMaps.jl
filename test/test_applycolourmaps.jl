# Test applycolourmaps.jl

# Tests could be more comprehensive (of course).  In some cases all
# that is done is to execute the function in some way just to make
# sure no exceptions are thrown as a result of something breaking with
# a new version of Julia.

println("testing applycolourmaps")

# applycolourmap
img = sineramp()
lmap = cmap("L1")
rnge = [10, 200]
rgbimg = applycolourmap(img, lmap)
rgbimg = applycolourmap(img, lmap, rnge)

# applycycliccolourmap
(ang, mask) = circlesineramp()
cycmap = cmap("C1")
rgbimg = applycycliccolourmap(ang, cycmap)
rgbimg = applycycliccolourmap(ang, cycmap, amp = ang, cyclelength = pi)

# applydivergingcolourmap
divmap = cmap("D1")
refval = 0
rgbim = applydivergingcolourmap(img, divmap, refval)

# ternaryimage
bands = [2, 3, 1]
histcut = 2
(rows,cols) = size(img)
cimg = zeros(rows,cols,3)
for n = 1:3
    cimg[:,:,n] = img
end
rgbimg = ternaryimage(cimg, bands=bands, histcut=histcut)
rgbimg = ternaryimage(cimg, bands=bands, histcut=histcut, RGB=false)

