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

using PyPlot
export viewlabspace

"""
viewlabspace:  Visualisation of L*a*b* space

```
Usage:    viewlabspace(L = 50, figNo = 1)

Arguments:     L - Lightness level in which to display slice of L*a*b* space
           figNo - PyPlot figure to use
```
Function allows interactive viewing of a sequence of images corresponding to
different slices of lightness in L*a*b* space.  Lightness varies from 0 to
100.  Initially a slice at a lightness of 50 is displayed.
Pressing 'l' or arrow up/right will increase the lightness by dL.
Pressing 'd' or arrow down/left will darken by dL.
Press 'x' to exit.

To Do:
The CIELAB colour coordinates of the cursor position within the slice images
should be updated continuously.  This is useful for determining suitable control
points for the definition of colourmap paths through CIELAB space in cmap().

See also: colourmappath, cmap
"""
function viewlabspace(L=50, figNo=1)
    # March 2013
    # November 2013  Interactive CIELAB coordinate feedback from mouse position
    # December 2015  Ported from MATLAB to Julia but loses interactivity...

    # Define some reference colours in rgb
    rgb = [1 0 0
           0 1 0
           0 0 1
           1 1 0
           0 1 1
           1 0 1]

    colours = ["red    "
               "green  "
               "blue   "
               "yellow "
               "cyan   "
               "magenta"]

    # ... and convert them to lab
    labv = srgb2lab(rgb)

    # Obtain cylindrical coordinates in lab space
    labradius = sqrt(labv[:,2].^2+labv[:,3].^2)
    labtheta = atan(labv[:,3], labv[:,2])

    # Define a*b* grid for image
    scale = 2;
    (a, b) = meshgrid(-127:1/scale:127)
    (rows,cols) = size(a)

    # Scale and offset lab coords to fit image coords
    labc = zeros(size(labv))
    labc[:,1] = round(labv[:,1])
    labc[:,2] = round(scale*labv[:,2] + cols/2)
    labc[:,3] = round(scale*labv[:,3] + rows/2)

    # Print out lab values
    labv = round(labv)
    @printf("\nCoordinates of standard colours in L*a*b* space\n\n");
    for n = 1:length(colours)
        @printf("%s  L%3d   a %4d  b %4d    angle %4.1f  radius %4d\n",
                colours[n], labv[n,1], labv[n,2], labv[n,3],
                labtheta[n], round(labradius[n]))
    end

    @printf("\n\n")

    # Generate axis tick values
    tickval = [-100, -50, 0, 50, 100]
    tickcoords = scale*tickval + cols/2
    ticklabels = ("-100", "-50", "0", "50", "100")


    renderlabslice(L, a, b, figNo, labv, labc, colours)

    @printf("Type in a desired Lightness value or type 'x' to exit\n\n")
    resp = ""
    while lowercase(resp) != 'x'
        resp = lowercase(readline())

        if resp[1] == 'x'
            break
        else
            try
                L = parse(Float64, resp)
                renderlabslice(L, a, b, figNo, labv, labc, colours)
            catch
                @printf("Type in a desired Lightness value or type 'x' to exit\n")
            end
        end
    end

end

#--------------------------------------------------------

function renderlabslice(L, a, b, figNo, labv, labc, colours)

    # Build image in lab space
    (rows,cols) = size(a)

    lab = zeros(rows,cols,3)
    lab[:,:,1] = L
    lab[:,:,2] = a
    lab[:,:,3] = b

    # Generate rgb values from lab
    rgb = lab2srgb(lab)

    # Invert to reconstruct the lab values
    lab2 = srgb2lab(rgb)

    # Where the reconstructed lab values differ from the specified values is
    # an indication that we have gone outside of the rgb gamut.  Apply a
    # mask to the rgb values accordingly
    mask = squeeze(maximum(abs(lab-lab2),3),3)

    for n = 1:3
        rgb[:,:,n] = rgb[:,:,n].*(mask.<2)  # tolerance of 2
    end

    figure(figNo)
    imshow(rgb, origin="lower", aspect="equal")
    title(@sprintf("Lab space:  Lightness %d", L))

    # Generate axis tick values
    tickval = [-100, -50, 0, 50, 100]
    scale = 2
    tickcoords = scale*tickval + cols/2
    ticklabels = ("-100", "-50", "0", "50", "100")
    xticks(tickcoords, ticklabels)
    yticks(tickcoords, ticklabels)

    xlabel("a*")
    ylabel("b*")

    hold(true),
    plot(cols/2, rows/2, "r+")   # Centre point for reference

    # Plot reference colour positions
    for n = 1:length(colours)
        plot(labc[n,2], labc[n,3], "w+")
        text(labc[n,2], labc[n,3],
             @sprintf("   %s\n  %d %d %d  ",colours[n],
                     labv[n,1], labv[n,2], labv[n,3]),
             color = [1, 1, 1])

    end

    hold(false)

end
