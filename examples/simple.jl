using Reactive, GeometryTypes, Colors, GLWindow, GLVisualize
import SignalView
window = glscreen()
@async renderloop(window)
# create a nice looking signal graph
root = Signal(1.0)
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
const heightmap = Float32[xy_data(x, y, value(root)) for x=range, y=range]

val = map(root) do v
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

using NetworkLayout.Buchheim



SignalView.view_signal(root, window)

dict = SignalView.to_adjency_dict(root)

for action in root.actions
    neighour_s = action.recipient.value
    @show neighour_s
    for action2 in neighour_s.actions
        @show action2.recipient.value
    end
end
root
adjecency_list, signal_nodes = SignalView.to_adjency_list(root)
adjecency_list
label_sizes = [100f0 for i=1:length(adjecency_list)]
points = Buchheim.layout(adjecency_list, nodesize=label_sizes)
_view(visualize((Circle, points)))
adjency_dict(root)
function adjency_dict(s::Signal, dict = Dict{Signal, Vector{Any}}(), neighbours = [])
    dict[s] = neighbours
    for action in s.actions
        neighour_s = action.recipient.value
        if neighour_s !=nothing && !haskey(dict, neighour_s)
            push!(neighbours, neighour_s)
            adjency_dict(neighour_s, dict)
        end
    end
    for parent_s in s.parents
        if !haskey(dict, parent_s)
            adjency_dict(parent_s, dict, Any[s])
        end
    end
    dict
end
