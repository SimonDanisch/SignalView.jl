using Reactive, SignalView, GeometryTypes, Colors, GLWindow, GLVisualize

window = glscreen()

# create a nice looking signal graph
t = Signal(1.0)
color_a = Signal(RGBA{Float32}(1,0,0,1))
color_b = Signal(RGBA{Float32}(0,0,1,1))

colormap = map(color_a, color_b) do a, b
    _a, _b = RGB{Float32}(a), RGB{Float32}(b)
    cmap = map(RGBA{Float32}, linspace(_a, _b, 20))
    reshape(cmap, (1, length(cmap)))
end

# generate some pretty data
function xy_data(x,y,i)
    Float32(sin(1.3*x*i)*cos(0.9*y)+cos(.8*x)*sin(1.9*y)+cos(y*.2*x))
end
const N = 128
const range = linspace(-5f0, 5f0, N)
const heightmap = Float32[xy_data(x, y, value(t)) for x=range, y=range]

val = map(t) do v
    v/10f0
end
"""
some nice looking surface function
"""
function contourdata(t)
    for i=1:size(heightmap, 1)
        @simd for j=1:size(heightmap, 2)
            @inbounds heightmap[i,j] = xy_data(t, range[i], range[j])
        end
    end
    heightmap
end

hmap_color = map(colormap, val) do c, t
    hmap = contourdata(t)
    cmap = vec(c)
    mini, maxi = first(range), last(range)
    # you can pass along a tuple of pairs, which will map to the keyword args of visualize
    ((hmap, :surface), (
        :color_map=>cmap,
        :color_norm=>Vec2f0(-1,2),
        :ranges => (range, range),
        :boundingbox=>AABB{Float32}(Vec3f0(mini, mini, -1f0), Vec3f0(maxi-mini, maxi-mini, 3f0))
    ))
end

# view it as a contourplot as well!
map(hmap_color) do hmap_color
    reinterpret(Intensity{1, Float32}, hmap_color[1][1])
end

view_signal(t, window)
renderloop(window)
