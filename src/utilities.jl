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

# Definition of some utility functions that are used by the colour map
# generation code.  These functions will eventually move into an image
# processing package that I am slowing building

export bbspline, pbsline, gaussfilt1d, interp1d, matprint
export normalise, normalize
export histtruncate, meshgrid
export sineramp, circlesineramp

#-----------------------------------------------------------------------
"""
bbspline - Basic B-spline
```
Usage:  S = bbspline(P, k, N)
 
Arguments:   P - [dim x Npts] array of control points
             k - order of spline (>= 2). 
                 k = 2: Linear
                 k = 3: Quadratic, etc
             N - Optional number of points to evaluate along
                 spline. Defaults to 100.

Returns:     S - spline curve  [dim x N] spline points
```
See also: pbspline
"""

# PK Jan 2014

function bbspline(P::Array, k::Int, N::Int = 100)
    
    (dim, np1) = size(P)
    n = np1-1

    @assert k >= 2   "Spline order must be 2 or greater"   
    @assert np1 >= k "No of control points must be >= k"
    @assert N >= 2   "Spline must be evaluated at 2 or more points"

    # Set up open uniform knot vector from 0 - 1.  
    # There are k repeated knots at each end.
    ti = collect(0:(k+n - 2*(k-1)))'
    ti = ti/ti[end]
    ti = [repmat([ti[1]], 1, k-1)  ti  repmat([ti[end]], 1, k-1)]
 
    nK = length(ti)
    
    # Generate values of t that the spline will be evaluated at
    dt = (ti[end]-ti[1])/(N-1)
    t = collect(ti[1]:dt:ti[end])'
    
    # Build complete array of basis functions.  We maintain two
    # arrays, one storing the basis functions at the current level of
    # recursion, and one storing the basis functions from the previous
    # level of recursion
    Blast = Array{Array{Float64}}(nK-1)
    B = Array{Array{Float64}}(nK-1)
    
    # 1st level of recursive construction
    for i = 1:nK-1
        if ti[i] < ti[i+1]
            Blast[i] = (t .>= ti[i]) & (t .< ti[i+1]) 
        else
            Blast[i] = zeros(1,N)
        end
    end

    # Subsequent levels of recursive basis construction.  Note the logic to
    # handle repeated knot values where ti[i] == ti[i+1]
    for ki = 2:k
        for i = 1:nK-ki
            if (ti[i+ki-1] - ti[i]) < eps()
                V1 = zeros(1,N)
            else
                V1 = (t - ti[i])/(ti[i+ki-1] - ti[i]) .* Blast[i]
            end
            
            if (ti[i+ki] - ti[i+1]) < eps()
                V2 = zeros(1,N)
            else
                V2 = (ti[i+ki] - t)/(ti[i+ki] - ti[i+1]) .* Blast[i+1]
            end
            
            B[i] = V1 + V2

            # This is the ideal equation that the code above implements            
            # B[i,ki] = (t - ti[i])/(ti[i+ki-1] - ti[i]) .* B[i,ki-1] + ...
            #           (ti[i+ki] - t)/(ti[i+ki] - ti[i+1]) .* B[i+1,ki-1]
        end
        # Swap B and Blast, but only if this is not the last iteration
        if ki < k
            tmp = Blast
            Blast = B
            B = tmp
        end
    end
    
    # Apply basis functions to the control points
    S = zeros(dim, length(t))

    for d = 1:dim, i = 1:np1
        S[d,:] += P[d,i]*B[i]
    end
    
    # Set the last point of the spline. This is not evaluated by the code above
    # because the basis functions are defined from ti[i] <= t < ti[i+1]
    S[:,end] = P[:,end]

    return S
end 

#-------------------------------------------------------------------------------
"""
pbspline - Basic Periodic B-spline
```
Usage:  S = pbspline(P, k, N)
 
Arguments:   P - [dim x Npts] array of control points
             k - order of spline (>= 2). 
                 k = 2: Linear
                 k = 3: Quadratic, etc
             N - Optional number of points to evaluate along
                 spline. Defaults to 100.

Returns:     S - spline curve  [dim x N] spline points
```
Note that the spline points are rotated so that the first point is as
close as possible to the first control point.  This is important for
the formation of cyclic paths in colour space.

See also: bbspline
"""
# PK March 2014
# Needs a bit of tidying up and checking on domain of curve
# Should be merged with bbspline

function pbspline(Pin::Array, k::Int, N::Int = 100)

    P = copy(Pin)  # Make a copy because we will be altering P
    
    # For a closed spline check if 1st and last control points match.  If not
    # add another control point so that they do match
    if norm(P[:,1] - P[:,end]) > 0.01
        P = [P P[:,1]]
    end
    
    # Now add k - 1 control points that wrap over the first control points
    P = [P P[:,2:2+k-1]]
    
    (dim, np1) = size(P)
    n = np1-1

    @assert k >= 2   "Spline order must be 2 or greater"
    @assert np1 >= k "No of control points must be >= k"
    @assert N >= 2   "Spline must be evaluated at 2 or more points"
    
    # Form a uniform sequence. Number of knot points is m + 1 where m = n + k + 1
    ti = collect(0:(n+k+1))/(n+k+1)'
    nK = length(ti)

    # Domain of curve is [ti_k to ti_n] or [ti_(k+1) to ti_(n+1)] ???
    tstart = ti[k]
    tend = ti[n]

    dt = (tend-tstart)/(N-1)
    t = collect(tstart:dt:tend)'
    
    # Build complete array of basis functions.  We maintain two
    # arrays, one storing the basis functions at the current level of
    # recursion, and one storing the basis functions from the previous
    # level of recursion
    Blast = Array{Array{Float64}}(nK-1)
    B = Array{Array{Float64}}(nK-1)

    # 1st level of recursive construction
    for i = 1:nK-1
        if t[i] < ti[i+1]
            Blast[i] = (t .>= ti[i]) & (t .< ti[i+1])
        else
            Blast[i] = zeros(1,N)
        end
    end

    # Subsequent levels of recursive basis construction.  Note the logic to
    # handle repeated knot values where ti[i] == ti[i+1]
    for ki = 2:k
        for i = 1:nK-ki

            if (ti[i+ki-1] - ti[i]) < eps()
                V1 = zeros(1,N)
            else
                V1 = (t - ti[i])/(ti[i+ki-1] - ti[i]) .* Blast[i]
            end
            
            if (ti[i+ki] - ti[i+1]) < eps()
                V2 = zeros(1,N)
            else
                V2 = (ti[i+ki] - t)/(ti[i+ki] - ti[i+1]) .* Blast[i+1]
            end
            
            B[i] = V1 + V2
            
            #       This is the ideal equation that the code above implements            
            #       B[i,ki] = (t - ti[i])/(ti[i+ki-1] - ti[i]) .* B[i,ki-1] + ...
            #                (ti[i+ki] - t)/(ti[i+ki] - ti[i+1]) .* B[i+1,ki-1]
        end
        # Swap B and Blast, but only if this is not the last iteration
        if ki < k
            tmp = Blast
            Blast = B
            B = tmp
        end
    end
    
    # Apply basis functions to the control points
    S = zeros(dim, length(t))
    
    for d = 1:dim, i = 1:np1
        S[d,:] += P[d,i]*B[i]
    end
    
    # Finally, because of the knot arrangements, the start of the spline may not
    # be close to the first control point if the spline order is 3 or greater.
    # Normally for a closed spline this is irrelevant.  However for our purpose
    # of using closed bplines to form paths in a colour space this is important to
    # us.  The simple brute force solution used here is to search through the
    # spline points for the point that is closest to the 1st control point and
    # then rotate the spline points accordingly
    
    distsqrd = zeros(size(S[1,:]))
    for d = 1:dim
        distsqrd += (S[d,:] - P[d,1]).^2
    end
    
    ind = indmin(distsqrd)
    
    return S = circshift(S, [0, -ind+1])
end


#----------------------------------------------------------------------------
# Function for applying a 1D Gaussian filter to a signal. Filtering at
# ends are done using zero padding
#
# Usage: sm = gaussfilt1d(s::Array, sigma::Real)

function gaussfilt1d(s::Array, sigma::Real)

    N = length(s)

    r = ceil(Int, 3*sigma)    # Determine filter size
    fw = 2*r + 1

    # Construct filter
    f = Float64[exp(-x.^2/(2*sigma)) for x = -r:r] 
    f = f/sum(f)

    sm = zeros(size(s))

    # Filter centre section
    for i = r+1:N-r, k = 1:fw
        sm[i] += f[k] * s[i+k-r-1]
    end

    # Filter start section of array using 0 padding
    for i = 1:r, k = 1:fw
        ind = i+k-r-1
        if ind >= 1 && ind <= N
            sm[i] += f[k] * s[ind]
        end
    end

    # Filter end section of array using 0 padding
    for i = N-r+1:N, k = 1:fw
        ind = i+k-r-1
        if ind >= 1 && ind <= N
            sm[i] += f[k] * s[ind]
        end
    end

    return sm
end


#----------------------------------------------------------------------------
"""
Simple 1D linear interpolation of an array of data

```
 Usage:  yi = interp1(x, y, xi)

```
Interpolates y, defined at values x, at locations xi and returns the
corresponding values as yi

x is assumed increasing but not necessarily equi-spaced.
xi values do not need to be sorted.
"""

#function interp1{T<:Real}(x::AbstractArray{T,1}, y::AbstractArray{T,1}, xi::Array{T,1})
function interp1(x, y, xi)

    N = length(xi)
    yi = zeros(size(xi))

    minx = minimum(x)
    maxx = maximum(x)

    for i = 1:N
        # Find interval in x that each xi lies within and interpolate its value

        if xi[i] <= minx
            yi[i] = y[1]

        elseif xi[i] >= maxx
            yi[i] = y[end]

        else
            left = maximum(find(x .<= xi[i]))
            right = minimum(find(x .> xi[i]))

            yi[i] = y[left] +  (xi[i]-x[left])/(x[right]-x[left]) * (y[right] - y[left])
        end
    end

    return yi
end

#----------------------------------------------------------------------------

function matprint(arr, str="")

    @printf("\n%s\n",str)

    if ndims(arr) == 1
        (rows,) = size(arr)
        @printf("[")
        for r=1:rows
            if r < rows
                @printf("%.3f, ",arr[r])
            else
                @printf("%.3f",arr[r])
            end
        end
        @printf("]\n")

    elseif ndims(arr) == 2
        (rows,cols) = size(arr)

        @printf("[")
        for r=1:rows
            if r>1
                @printf(" ")
            end
            for c=1:cols
                @printf("%.3f ",arr[r,c])
            end
            if r<rows
                @printf("\n")
            else
                @printf("]\n")
            end
        end
    end
end



#----------------------------------------------------------------------
"""
normalise/normalize - Normalises image values to 0-1, or to desired mean and variance

```
Usage 1:      nimg = normalise(img)
```
Offsets and rescales image so that the minimum value is 0
and the maximum value is 1.  

```
Usage 2:      nimg = normalise(img, reqmean, reqvar)

Arguments:  img     - A grey-level input image.
            reqmean - The required mean value of the image.
            reqvar  - The required variance of the image.
```
Offsets and rescales image so that nimg has mean reqmean and variance
reqvar.  
"""

# Normalise 0 - 1
function normalise(img::Array) 
    n = img - minimum(img)
    return n = n/maximum(n)
end

# Normalise to desired mean and variance
function normalise(img::Array, reqmean::Real, reqvar::Real)
    n = img - mean(img)
    n = n/std(img)      # Zero mean, unit std dev
    return n = reqmean + n*sqrt(reqvar)
end

# For those who spell normalise with a 'z'
"""
normalize - Normalizes image values to 0-1, or to desired mean and variance
```
Usage 1:      nimg = normalize(img)
```
Offsets and rescales image so that the minimum value is 0
and the maximum value is 1.  
```
Usage 2:      nimg = normalize(img, reqmean, reqvar)

Arguments:  img     - A grey-level input image.
            reqmean - The required mean value of the image.
            reqvar  - The required variance of the image.
```
Offsets and rescales image so that nimg has mean reqmean and variance
reqvar.  
"""

function normalize(img::Array) 
    return normalise(img)
end

function normalize(img::Array, reqmean::Real, reqvar::Real)
    return normalise(img, reqmean, reqvar)
end

#----------------------------------------------------------------------
"""
histtruncate - Truncates ends of an image histogram.

Function truncates a specified percentage of the lower and
upper ends of an image histogram.

This operation allows grey levels to be distributed across
the primary part of the histogram.  This solves the problem
when one has, say, a few very bright values in the image which
have the overall effect of darkening the rest of the image after
rescaling.

```
Usage: 
1)   newimg = histtruncate(img, lHistCut, uHistCut)
2)   newimg = histtruncate(img, HistCut)

Arguments:
 Usage 1)
   img         -  Image to be processed.
   lHistCut    -  Percentage of the lower end of the histogram
                  to saturate.
   uHistCut    -  Percentage of the upper end of the histogram
                  to saturate.  If omitted or empty defaults to the value
                  for lHistCut.
 Usage 2)
   HistCut     -  Percentage of upper and lower ends of the histogram to cut.

Returns:
   newimg      -  Image with values clipped at the specified histogram
                  fraction values.  If the input image was colour the
                  lightness values are clipped and stretched to the range
                  0-1.  If the input image is greyscale no stretching is
                  applied. You may want to use normalise() to achieve this.
```
See also: normalise
"""

# July      2001 - Original version
# February  2012 - Added handling of NaN values in image
# February  2014 - Code cleanup
# September 2014 - Default for uHistCut + cleanup

function  histtruncate(img::Array, lHistCut::Real, uHistCut::Real)
    
    if lHistCut < 0 || lHistCut > 100 || uHistCut < 0 || uHistCut > 100
	error("Histogram truncation values must be between 0 and 100")
    end
    
    if ndims(img) > 2
	error("histtruncate only defined for grey scale images")
    end

    newimg = copy(img)    
    sortv = sort(newimg[:])   # Generate a sorted array of pixel values.

    # Any NaN values will end up at the end of the sorted list. We
    # need to ignore these.
    N = sum(!isnan(sortv))  # Number of non NaN values.
    
    # Compute indicies corresponding to specified upper and lower fractions
    # of the histogram.
    lind = floor(Int, 1 + N*lHistCut/100)
    hind =  ceil(Int, N - N*uHistCut/100)

    low_val  = sortv[lind]
    high_val = sortv[hind]

    # Adjust image
    newimg[newimg .< low_val] = low_val
    newimg[newimg .> high_val] = high_val
    
    return newimg
end


function  histtruncate(img::Array, HistCut::Real)
    return histtruncate(img, HistCut, HistCut)
end


#----------------------------------------------------------------------
"""          
sineramp  - Generates sine on a ramp colour map test image

The test image consists of a sine wave superimposed on a ramp function The
amplitude of the sine wave is modulated from its full value at the top of the
image to 0 at the bottom. 

The image is useful for evaluating the effectiveness of different colour maps.
Ideally the sine wave pattern should be equally discernible over the full
range of the colour map.  In addition, across the bottom of the image, one
should not see any identifiable features as the underlying signal is a smooth
ramp.  In practice many colour maps have uneven perceptual contrast over their
range and often include 'flat spots' of no perceptual contrast that can hide
significant features.

```
Usage: img = sineramp(sze, amp, wavelen, p)
       img = sineramp()

Arguments:     sze - (rows, cols) specifying size of test image.  
                     Defaults to (256 512)  Note the number of columns is
                     nominal and will be ajusted so that there are an
                     integer number of sine wave cycles across the image.
               amp - Amplitude of sine wave. Defaults to 12.5
           wavelen - Wavelength of sine wave in pixels. Defaults to 8.
                 p - Power to which the linear attenuation of amplitude, 
                     from top to bottom, is raised.  For no attenuation use
                     p = 0.  For linear attenuation use a value of 1.  For
                     contrast sensitivity experiments use larger values of
                     p.  The default value is 2. 
``` 
The ramp function that the sine wave is superimposed on is adjusted slightly
for each row so that each row of the image spans the full data range of 0 to
255.  Thus using a large sine wave amplitude will result in the ramp at the
top of the test image being reduced relative to the slope of the ramp at
the bottom of the image.

To start with try

```
  > img = sineramp()
```
This is equivalent to 

```
  > img = sineramp((256 512), 12.5, 8, 2)
```
View it under 'gray' then try the 'jet', 'hsv', 'hot' etc colour maps.  The
results may cause you some concern!

If you are wishing to evaluate a cyclic colour map, say hsv, it is suggested
that you use the test image generated by circlesineramp().  

See source code comments for more details on the default wavelength
and amplitude.

See also: circlesineramp, chirplin, chirpexp, equalisecolourmap, cmap
"""
#=
The Default Wavelength:
The default wavelength is 8 pixels.  On a computer monitor with a nominal
pixel pitch of 0.25mm this corresponds to a wavelength of 2mm.  With a monitor
viewing distance of 600mm this corresponds to 0.19 degrees of viewing angle or
approximately 5.2 cycles per degree.  This falls within the range of spatial
frequencies (3-7 cycles per degree ) at which most people have maximal
contrast sensitivity to a sine wave grating (this varies with mean luminance).
A wavelength of 8 pixels is also sufficient to provide a reasonable discrete
representation of a sine wave.  The aim is to present a stimulus that is well
matched to the performance of the human visual system so that what we are
primarily evaluating is the colour map's perceptual contrast and not the visual
performance of the viewer.

The Default Amplitude:
This is set at 12.5 so that from peak to trough we have a local feature of
magnitude 25.  This is approximately 10% of the 256 levels in a standard
colour map. It is not uncommon for colour maps to have perceptual flat spots
that can hide features of this magnitude.
=#

# July  2013  Original version.
# March 2014  Adjustments to make it better for evaluating cyclic colour maps.
# June  2014  Default wavelength changed from 10 to 8.

# ** Should I make this function return UInt8 values ?**

function sineramp(sze=(256,512), amp=12.5, wavelen=8, p=2)
    
    # Adjust width of image so that we have an integer number of cycles of
    # the sinewave.  This is helps should one be using the test image to
    # evaluate a cyclic colour map.  However you will still see a slight
    # cyclic discontinuity at the top of the image, though this will
    # disappear at the bottom of the test image
    
    (rows,cols) = sze
    cycles = round(cols/wavelen)
    cols = cycles*wavelen
    
    # Sine wave
    x = collect(0:cols-1)'
    fx = amp*sin( 1.0/wavelen * 2*pi*x)
    
    # Vertical modulating function
    A = (collect((rows-1):-1:0)'/(rows-1)).^float(p)
    img = A'*fx
    
    # Add ramp
    ramp,_ = meshgrid(0:(cols-1), 1:rows)
    ramp = ramp/(cols-1)
    img = img + ramp*(255.0 - 2*amp)
    
    # Now normalise each row so that it spans the full data range from 0 to 255.
    # Again, this is important for evaluation of cyclic colour maps though a
    # small cyclic discontinuity will remain at the top of the test image.
    for r = 1:rows
        img[r,:] = normalise(img[r,:])
    end
    img = img * 255.0
    return img
end

#----------------------------------------------------------------------
"""           
circlesineramp - Generates a test image for evaluating cyclic colour maps

```
Usage: (img, alpha) = circlesineramp(sze, amp, wavelen, p, hole)
       (img, alpha) = circlesineramp()

Arguments:     sze - Size of test image.  Defaults to 512x512.
               amp - Amplitude of sine wave. Defaults to pi/10
           wavelen - Wavelength of sine wave at half radius of the
                     circular test image. Defaults to 8 pixels.
                 p - Power to which the linear attenuation of amplitude, 
                     from outside edge to centre, is raised.  For no
                     attenuation use p = 0.  For linear attenuation use a
                     value of 1.  The default value is 2, quadratic
                     attenuation. 
              hole - Flag 0/1 indicating whether the test image should have
                     a 'hole' in its centre.  The default is 1, to have a
                     hole, this removes the distraction of the orientation
                     singularlity at the centre.
Returns:
                im - The test image.
             alpha - Alpha mask matching the regions outside of of the
                     circular test image that are set to NaN.  Used if you
                     want to write an image with these regions transparent.
```
The test image is a circular pattern consistsing of a sine wave superimposed
on a spiral ramp function.  The spiral ramp starts at a value of 0 pointing
right, increasing anti-clockwise to a value of 2*pi as it completes the full
circle. This gives a 2*pi discontinuity on the right side of the image.  The
amplitude of the superimposed sine wave is modulated from its full value at
the outside of the circular pattern to 0 at the centre.  The default sine wave
amplitude of pi/10 means that the overall size of the sine wave from peak to
trough represents 2*(pi/10)/(2*pi) = 10% of the total spiral ramp of 2*pi.  If
you are testing your colour map over a cycle of pi you should use amp = pi/20
to obtain an equivalent ratio of sine wave to circular ramp.

The image is designed for evaluating the effectiveness of cyclic colour maps.
It is the cyclic companion to sineramp().  Ideally the sine wave pattern should
be equally discernible over all angles around the test image.  In practice
many colourmaps have uneven perceptual contrast over their range and often
include 'flat spots' of no perceptual contrast that can hide significant
features.  Try a HSV colour map.

Ideally the test image should be rendered with a cyclic colour map using
showangularim() though, in this case, rendering the image with SHOW or IMAGESC
will also be fine because all image values lie within, and use the full range
of, 0-2*pi.  However, in general, default display methods typically do not
respect data values directly and can perform inappropriate offsetting and
normalisation of the angular data before display and rendering with a colour
map.

For angular data to be rendered correctly it is important that the data values
are respected so that data values are correctly assigned to specific entries
in a cyclic colour map.  The assignment of values to colours also depends on
whether the data is cyclic over pi, or 2*pi.  SHOWANGULARIM supports this.

See also: applycycliccolourmap, sineramp, chirplin, chirpexp, equalisecolourmap, cmap
"""
# September 2014  Original version.
# October   2014  Number of cycles calculated from wave length rather than
#                 being specified directly.

function circlesineramp(sze=512, amp=pi/10, wavelen=8, p=2, hole=true)
    
    # Set values for inner and outer radii of test pattern
    maxr = sze/2 * 0.9
    if hole
        minr = 0.15*sze
    else
        minr = 0
    end
    
    # Determine number of cycles to achieve desired wavelength at half radius
    meanr = (maxr + minr)/2
    circum = 2*pi*meanr
    cycles = round(circum/wavelen)
    
    # Angles are +ve anticlockwise and mod 2*pi
    (x,y) = meshgrid((0:sze-1) -sze/2)
    theta = mod(atan2(-y,x), 2*pi)  
    rad = sqrt(x.^2 + y.^2)
    
    # Normalise radius so that it varies 0-1 over minr to maxr
    rad = (rad-minr)/(maxr-minr)
    
    # Form the image
    img = amp*rad.^float(p) .* sin(cycles*theta) + theta

    # Ensure all values are within 0-2*pi so that a simple default display
    # with a cyclic colour map will render the image correctly.
    img = mod(img, 2*pi)

    # 'Nanify' values outside normalised radius values of 0-1
    alpha = ones(size(img))
    img[rad .> 1] = NaN  
    alpha[rad .> 1] = 0

    if hole
        img[rad .< 0] = NaN 
        alpha[rad .< 0] = 0
    end

   return img, alpha
end

#----------------------------------------------------------------------
"""
meshgrid - Generates cartesian grid in 2D space
```
Usage: (x, y) = meshgrid(xrange, yrange)

       (x, y) = meshgrid(xyrange)

Arguments: 
      xrange, yrange - Ranges or vectors defining the values to 
                       be placed in the cartesian grid.

             xyrange - Range of vector that is to be used for both x and y.

Returns:  x, y - Arrays of size length(yrange) x length(xrange)
                 defining the cartesian grid
```

Simple replacement for MATLAB's meshgrid function.

"""

# Various versions for different argument types

function meshgrid(xrange::Range, yrange::Range)
    return meshgrid(collect(xrange), collect(yrange))
end

function meshgrid(xrange::Range, yrange::Vector)
    return meshgrid(collect(xrange), collect(yrange))
end

function meshgrid(xrange::Vector, yrange::Range)
    return meshgrid(collect(xrange), collect(yrange))
end

function meshgrid(xyrange::Vector)
    return meshgrid(collect(xyrange), collect(xyrange))
end

function meshgrid(xyrange::Range)
    return meshgrid(collect(xyrange), collect(xyrange))
end

# Vector version
function meshgrid(xrange::Vector, yrange::Vector)
    
    rows = length(yrange)
    cols = length(xrange)

    x = repmat(collect(xrange)', rows, 1)
    y = repmat(collect(yrange) , 1, cols)

    return x,y
end

