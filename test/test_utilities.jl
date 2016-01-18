# Test utililties.jl

# Tests could be more comprehensive (of course).  In some cases all
# that is done is to execute the function in some way just to make
# sure no exceptions are thrown as a result of something breaking with
# a new version of Julia.

println("testing utilites")

# bbspline
P = [0 1 2 3
     0 1 2 3]
k = 3
N = 10
S = bbspline(P, k, N)
dx = gradient(vec(S[1,:]))
dy = gradient(vec(S[2,:]))
slope = dy./dx
@test maximum(slope - 1) < 1e-3

# pbspline
P = [0 1 2 3 0
     0 1 2 3 0]
k = 3
N = 100
S = pbspline(P, k, N)

# gaussfilt1d
a = zeros(20,1)
a[10] = 1
sigma = 2
sa = gaussfilt1d(a, sigma)
@test abs(sa[10] - 0.282) < 1e-3
@test abs(sum(sa) - 1) < 1e-3

# interp1
x = [0, 2, 7]
y = 2*x
xi = [1.1, 0.5, 6]
yi = interp1(x,y,xi)
@test maximum(abs(yi - 2*xi) .< eps())

# normalise
a = rand(5,3)
an = normalise(a)
@test isapprox(minimum(an), 0)
@test isapprox(maximum(an), 1)

reqmean = 5
reqvar = 7
an = normalise(a, reqmean, reqvar)
@test isapprox(mean(an), reqmean)
@test isapprox(var(an), reqvar)

# histtruncate
rows = 100;
cols = 200;
img = rand(rows, cols)
lHistCut = 2
uHistCut = 4
htimg = histtruncate(img, lHistCut, uHistCut)
minval = minimum(htimg)
maxval = maximum(htimg)
# Check that the number of saturated pixels at each extreme is
# approximately lHistCut and uHistCut. Note some integer rounding has
# to occur.
v = find(abs(htimg-minval).<eps())
@test abs(length(v)/(rows*cols) * 100 - lHistCut) < 1

v = find(abs(htimg-maxval).<eps())
@test abs(length(v)/(rows*cols) * 100 - uHistCut) < 1

# sineramp
sr = sineramp()
sr = sineramp((256, 512), 12.5, 8, 2)

# circlesineramp
(img, alpha) = circlesineramp()
(img, alpha) = circlesineramp(512, pi/10, 8, 2, false)

# meshgrid
xrange = -3:2
yrange = 2:.5:6
(x,y) = meshgrid(xrange, yrange) # two arguments
(rows,cols) = size(x)
for r = 1:rows
    @test all(x[r:r,:] .== xrange')
end
for c = 1:cols
    @test all(y[:,c:c] .== yrange)
end

arange = 2:.1:4
(x,y) = meshgrid(arange)  # one argument
(rows,cols) = size(x)
for r = 1:rows
    @test all(x[r:r,:] .== arange')
end
for c = 1:cols
    @test all(y[:,c:c] .== arange)
end
