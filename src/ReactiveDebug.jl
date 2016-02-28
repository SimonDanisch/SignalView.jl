module ReactiveDebug

using GeometryTypes, Reactive
import GraphLayout
import GraphLayout: AdjList
"""
    Assigns layers using the longest path method.
    Arguments:
    adj_list        Directed graph in adjacency list format
"""
function _layer_assmt_longestpath{T}(adj_list::AdjList{T})
    n = length(adj_list)
    layers = fill(-1, n)

    for j in 1:n
        in_deg = 0
        for i in 1:n
            if j in adj_list[i]
                in_deg += 1
            end
        end
        if in_deg == 0
            # Start recursive walk from this vertex
            layers[j] = 1
            _layer_assmt_longestpath_rec(adj_list, layers, j)
        end
    end

    return layers
end


"""
    Given a layer assignment, introduce dummy vertices to break up
    long edges (more than one layer)
    Arguments:
    orig_adj_list   Original directed graph in adjacency list format
    layers          Assignment of original vertices
"""
function _layer_assmt_dummy{T}(orig_adj_list::AdjList{T}, layers)
    adj_list = deepcopy(orig_adj_list)

    # This is essentially
    # for i in 1:length(adj_list)
    # but the adj_list is growing in the loop
    i = 1
    while i <= length(adj_list)
        for (k,j) in enumerate(adj_list[i])
            if layers[j] - layers[i] > 1
                # Need to add a dummy vertex
                new_v = length(adj_list) + 1
                adj_list[i][k] = new_v  # Replace dest of cur edge
                push!(adj_list, Int[j])  # Add new edge
                push!(layers, layers[i]+1)  # Layer for new edge
            end
        end
        i += 1
    end

    return adj_list, layers
end

function _layer_assmt_longestpath_rec{T}(adj_list::AdjList{T}, layers, i)
    # Look for all children of vertex i, try to bump their layer
    n = length(adj_list)
    for j in adj_list[i]
        if layers[j] == -1 || layers[j] <= layers[i]
            layers[j] = layers[i] + 1
            _layer_assmt_longestpath_rec(adj_list, layers, j)
        end
    end
end


"""
    Given a layer assignment, decide a permutation for each layer
    that attempts to minimizes edge crossings using the barycenter
    method proposed in the Sugiyama paper.
    Arguments:
    adj_list        Directed graph in adjacency list format
    layers          Assignment of vertices
    layer_verts     Dictionary of layer => vertices
"""
function _ordering_barycentric{T}(adj_list::AdjList{T}, layers, layer_verts)
    num_layers = maximum(layers)
    n = length(adj_list)

    for iter in 1:5
        # DOWN
        for L in 1:num_layers-1
            # Calculate barycenter for every vertex in next layer
            cur_layer = layer_verts[L]
            next_layer = layer_verts[L+1]
            barys = zeros(n)
            in_deg = zeros(n)
            for (p,i) in enumerate(cur_layer)
                # Because of the dummy vertices we know that
                # all vertices in adj list for i are in next layer
                for (q,j) in enumerate(adj_list[i])
                    barys[j] += p
                    in_deg[j] += 1
                end
            end
            barys ./= in_deg
            # Arrange next layer by barys, in ascending order
            next_layer_barys = [barys[j] for j in next_layer]
            #println("DOWN $L")
            #println(next_layer)
            #println(next_layer_barys)
            layer_verts[L+1] = next_layer[sortperm(next_layer_barys)]
        end
        # UP
        for L in num_layers-1:-1:1
            # Calculate barycenters for every vertex in cur layer
            cur_layer = layer_verts[L]
            next_layer = layer_verts[L+1]
            barys = zeros(n)
            out_deg = zeros(n)
            for (p,i) in enumerate(cur_layer)
                # Because of the dummy vertices we know that
                # all vertices in adj list for i are in next layer
                # We need to know their positions in next layer
                # though, unfortunately. Probably a smarter way
                # to do this step
                for (q,j) in enumerate(adj_list[i])
                    # Find position in next layer
                    for (r,k) in enumerate(next_layer)
                        if k == j
                            barys[i] += r
                            out_deg[i] += 1
                            break
                        end
                    end
                end
            end
            barys ./= out_deg
            # Arrange cur layer by barys, in ascending order
            cur_layer_barys = [barys[j] for j in cur_layer]
            #println("UP $L")
            #println(cur_layer)
            #println(cur_layer_barys)
            layer_verts[L] = cur_layer[sortperm(cur_layer_barys)]
        end
        # Do something with phase 2 here - don't really understand
    end

    return layer_verts
end


function _tree_rectangle(x, y, rect)
    SimpleRectangle(rect.x + x - rect.w/2, rect.y + y - rect.w/2, rect.w, rect.h)
end

"""
    Creates an arrow between two rectangles in the tree

    Arguments:
    o_x, o_y, o_h   Origin x, y, and height
    d_x, d_y, d_h   Destination x, y, and height
"""
function _arrow_tree{T}(origin::Point{2,T}, o_h::T, destination::Point{2,T}, d_h::T)
    x1, y1 = origin[1], origin[2] + o_h/2
    x2, y2 = destination[1], destination[2] - d_h/2
    Δx, Δy = x2 - x1, y2 - y1
    θ = atan2(Δy, Δx)
    # Put an arrow head only if destination isn't dummy
    head = d_h != 0 ? _arrow_heads(θ, x2, y2, T(2)) : []
    start = Point{2,T}(x1, y1)
    endpoint = Point{2,T}(x2, y2)
    LineSegment{Point{2,T}}[LineSegment{Point{2,T}}(start, endpoint), head...]
end
"""
    Creates an arrow head given the angle of the arrow and its destination.

    Arguments:
    θ               Angle of arrow (radians)
    dest_x, dest_y  End of arrow
    λ               Length of arrow head tips
    ϕ               Angle of arrow head tips relative to angle of arrow
"""
function _arrow_heads{T}(θ::T, dest_x::T, dest_y::T, λ::T, ϕ=T(0.125π))
    left = Point{2,T}(dest_x - λ*cos(θ+ϕ), dest_y - λ*sin(θ+ϕ))
    pointy = Point{2,T}(dest_x, dest_y)
    right = Point{2,T}(dest_x - λ*cos(θ-ϕ), dest_y - λ*sin(θ-ϕ))
    LineSegment{Point{2,T}}[
        (left, pointy)
        (pointy, left)
    ]
end


function layout_tree{T<:Integer, R<:SimpleRectangle}(
        adj_list::AdjList{T},
        labels::Vector{R};
        ordering    = :optimal,
        coord       = :optimal,
        xsep        = 50,
        ysep        = 120,
        scale       = 0.05,
        labelpad    = 1.2,
    )
    # Calculate the original number of vertices
    n = length(adj_list)
    TV = fieldtype(R, :x)

    # 2     Layering
    # 2.1   Assign a layer to each vertex
    layers = _layer_assmt_longestpath(adj_list)
    num_layers = maximum(layers)
    # 2.2  Create dummy vertices for long edges
    adj_list, layers = _layer_assmt_dummy(adj_list, layers)
    orig_n, n = n, length(adj_list)


    # 3     Vertex ordering [to reduce crossings]
    # 3.1   Build initial permutation vectors
    layer_verts = [L => Int[] for L in 1:num_layers]
    for i in 1:n
        push!(layer_verts[layers[i]], i)
    end
    # 3.2  Reorder permutations to reduce crossings
    if ordering == :barycentric
        layer_verts = _ordering_barycentric(adj_list, layers, layer_verts)
    elseif ordering == :optimal
        layer_verts = GraphLayout._ordering_ip(adj_list, layers, layer_verts)
    end


    # 4     Vertex coordinates [to straighten edges]
    # 4.1   Place y coordinates in layers
    locs_y = zeros(TV, n)
    for L in 1:num_layers
        for (x,v) in enumerate(layer_verts[L])
            locs_y[v] = (L-1)*ysep
        end
    end
    # 4.2   Get widths of each label, if there are any
    widths_  = ones(TV, n); widths_[orig_n+1:n]  = 0
    heights = ones(TV, n); heights[orig_n+1:n] = 0
    # Note that we will convert these sizes into "absolute" units
    # and then work in these same units throughout. The font size used
    # here is just arbitrary, and unchanging. This hack arises because it
    # is meaningless to ask for the size of the font in "relative" units
    # but we don't want to collapse to absolute units until the end.
    if length(labels) == orig_n
        @inbounds for (i, rect) in enumerate(labels)
            w, h = Vec{2, TV}(widths(rect))
            widths_[i]  = w
            heights[i] = h
        end
    end
    locs_x = convert(Vector{TV}, GraphLayout._coord_ip(adj_list, layers, layer_verts, orig_n, widths_, xsep))
    # 4.3   Summarize vertex info
    max_x, max_y = maximum(locs_x), maximum(locs_y)
    max_w, max_h = maximum(widths_), maximum(heights)

    # 5     Draw the tree
    # 5.1   Create the vertices
    positioned_rectangles = [_tree_rectangle(locs_x[i], locs_y[i], labels[i]) for i in 1:orig_n]
    # 5.2   Create the arrows
    lines = LineSegment{Point{2,TV}}[]
    for L in 1:num_layers, i in layer_verts[L], j in adj_list[i]
        node_lines = _arrow_tree(
            Point{2,TV}(locs_x[i], locs_y[i]), i<=orig_n ? max_h : TV(0),
            Point{2,TV}(locs_x[j], locs_y[j]), j<=orig_n ? max_h : TV(0)
        )
        append!(lines, node_lines)
    end

    return positioned_rectangles, lines
end


function to_adjency_dict(s::Signal, adjecency_dict = Dict{Signal, Vector{Any}}(), neighbours = [])
    adjecency_dict[s] = neighbours
    for action in s.actions
        neighour_s = action.recipient.value
        if !haskey(adjecency_dict, neighour_s)
            push!(neighbours, neighour_s)
            to_adjency_dict(neighour_s, adjecency_dict)
        end
    end
    for parent_s in s.parents
        if !haskey(adjecency_dict, parent_s)
            to_adjency_dict(parent_s, adjecency_dict, Any[s])
        end
    end
    adjecency_dict
end

function to_adjency_list(s::Signal)
    dict = to_adjency_dict(s)
    adjecency_list = Vector{Int}[]
    labels = Signal[]
    pos_in_adjecency = Dict{Signal, Int}()
    # Initialize neighbours in adjecency_list
    for (signal, v) in dict
        push!(adjecency_list, Int[])
        push!(labels, signal)
        pos_in_adjecency[signal] = length(adjecency_list)
    end
    # fill neighbours
    for (signal, neighbours) in dict
        neighbourlist = adjecency_list[pos_in_adjecency[signal]]
        for neighbour in neighbours
            push!(neighbourlist, pos_in_adjecency[neighbour])
        end
    end
    adjecency_list, labels
end
export to_adjency_list, layout_tree
end # module
