"""
Fallback for signals that are not visualizable
"""
function GLVisualize._default(s::Signal, style::GLAbstraction.Style, data)
    GLVisualize._default(map(string, s), style, data)
end

get_pairval(pairtuple, i) = pairtuple[i][2]

"""
Visualization of tuples with kw_args
"""
function GLVisualize.visualize{X, KW_ARGS<:Tuple}(
        v_kw_args::Signal{Tuple{X, KW_ARGS}},
        style::GLAbstraction.Style, data
    )
    to_visualize = map(first, v_kw_args)
    val = value(to_visualize)
    if isa(val, Tuple)
        to_visualize = map(first, to_visualize)
        style = Style{val[2]}()
    end
    kw_args = map(last, v_kw_args)
    for (i, (name, val)) in enumerate(value(kw_args))
        data[name] = const_lift(get_pairval, kw_args, i)
    end
    visualize(to_visualize, style, data)
end

"""
Visualization of a graph with Rects and Lines
"""
function GLVisualize.visualize{R<:SimpleRectangle, L<:LineSegment}(
        rects_lines::Tuple{Vector{R}, Vector{L}},
        style::GLAbstraction.Style, data
    )
    rects, lines = rects_lines
    positions = Point2f0[Point2f0(r.x, r.y) for r in rects]
    scales = Vec2f0[Vec2f0(r.w, r.h) for r in rects]

    rect_vis = visualize((SimpleRectangle, positions), scale=scales,
        color=RGBA{Float32}(0,0,0,0),
        stroke_width=2f0,
        stroke_color=GLVisualize.default(RGBA)
    )
    line_vis = visualize(lines; data...)

    Context(rect_vis, line_vis)
end

function view_signal(signal::Signal, window)
    adjecency_list, signal_nodes = to_adjency_list(signal)
    label_sizes = [SimpleRectangle(0f0, 0f0, 100f0, 100f0) for i=1:length(adjecency_list)]
    rects, lines = GraphLayout.layout_tree(adjecency_list, label_sizes)

    graph = visualize((rects, lines))
    view(graph, window)
    for (area, s) in zip(rects, signal_nodes)
        s_area = map(window.cameras[:orthographic_pixel].projectionview, window.inputs[:framebuffer_size]) do pv, fs
            xy = Vec4f0(area.x+2, area.y+2, 0, 1)
            xywh = Vec4f0(xy[1]+area.w-4, xy[2]+area.h-4, 0, 1)
            _xy = round(((Vec2f0(pv * xy) + 1f0)/2f0) .* fs)
            _wh = round(((Vec2f0(pv * xywh) + 1f0)/2f0) .* fs)
            SimpleRectangle{Int}(_xy..., (_wh-_xy)...)
        end
        screen = Screen(window, area=s_area)
        if applicable(vizzedit, s, screen)
            _s, vis = vizzedit(s, screen)
        else
            vis = visualize(s)
        end

        view(vis, screen)
        center!(screen, vis.children[][:preferred_camera])
    end
end
