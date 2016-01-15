# Test relief.jl

# Tests could be more comprehensive (of course).  In some cases all
# that is done is to execute the function in some way just to make
# sure no exceptions are thrown as a result of something breaking with
# a new version of Julia.

println("testing relief")

img = sineramp()

rimg = relief(img)
az = 45
el = 45
gradscale = 2
rimg = relief(img, az, el, gradscale, cmap("L10")[1])
rimg = relief(img, az, el, gradscale)
