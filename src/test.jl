using Reactive, ReactiveDebug, GeometryTypes, Colors, GLWindow



a = Signal(2)
b = Signal(1.0)
c = map(+, a, b)
color = Signal(RGBA{Float32}(1,0,0,1))

e = map(+, a, Signal(0))
d = map(sqrt, c)
wow = map(d, color) do _d, c
    RGBA{U8}[RGBA{U8}((sin(x)+1)/2, (sin(y)+1)/2, clamp(_d+c.b, 0, 1), c.alpha) for x=linspace(0,2pi,256), y=linspace(0,2pi,256)]
end

wowow = map(b) do r
    GLNormalMesh(Sphere(Point3f0(0), Float32(r)))
end


adjecency_list, signal_nodes = to_adjency_list(a)
labels = [SimpleRectangle(0f0, 0f0, 100f0, 100f0) for i=1:length(adjecency_list)]
rects, lines = layout_tree(adjecency_list, labels)

positions = Point2f0[Point2f0(r.x, r.y) for r in rects]
scales = Vec2f0[Vec2f0(r.w, r.h) for r in rects]
using GLVisualize, GLAbstraction
w=glscreen()

signal_boundingbox(robj) = value(boundingbox(robj))
function center_cam(camera::PerspectiveCamera, renderlist)
    isempty(renderlist) && return nothing # nothing to do here
    # reset camera
    push!(camera.up, Vec3f0(0,0,1))
    push!(camera.eyeposition, Vec3f0(3))
    push!(camera.lookat, Vec3f0(0))

    robj1 = first(renderlist)
    bb = value(robj1[:model])*signal_boundingbox(robj1)
    for elem in renderlist[2:end]
        bb = union(value(elem[:model])*signal_boundingbox(elem), bb)
    end
    width        = widths(bb)
    half_width   = width/2f0
    lower_corner = minimum(bb)
    middle       = maximum(bb) - half_width
    if value(camera.projectiontype) == ORTHOGRAPHIC
        area, fov, near, far = map(value,
            (camera.window_size, camera.fov, camera.nearclip, camera.farclip)
        )
        h = Float32(tan(fov / 360.0 * pi) * near)
        w_, h_, _ = half_width

        zoom = min(h_,w_)/h
        push!(camera.up, Vec3f0(0,1,0))
        x,y,_ = middle
        push!(camera.eyeposition, Vec3f0(x, y, zoom*2))
        push!(camera.lookat, Vec3f0(x, y, 0))
        push!(camera.farclip, zoom*2f0)

    else
        zoom = norm(half_width)
        push!(camera.lookat, middle)
        neweyepos = middle + (zoom*Vec3f0(1.2))
        push!(camera.eyeposition, neweyepos)
        push!(camera.up, Vec3f0(0,0,1))
        push!(camera.farclip, zoom*50f0)
    end
end

view(visualize((SimpleRectangle, positions), scale=scales,
    color=RGBA{Float32}(0,0,0,0),
    stroke_width=2f0,
    stroke_color=GLVisualize.default(RGBA)
), w)
# add a fallback for non visualizable signals
function GLVisualize._default(s::Signal, style::GLAbstraction.Style, data)
    GLVisualize._default(map(string, s), style, data)
end
for (area, s) in zip(rects, signal_nodes)
    a = map(w.cameras[:orthographic_pixel].projectionview, w.inputs[:framebuffer_size]) do pv, fs
        xy = Vec4f0(area.x+2, area.y+2, 0, 1)
        xywh = Vec4f0(xy[1]+area.w-4, xy[2]+area.h-4, 0, 1)
        _xy = round(((Vec2f0(pv * xy) + 1f0)/2f0) .* fs)
        _wh = round(((Vec2f0(pv * xywh) + 1f0)/2f0) .* fs)
        SimpleRectangle{Int}(_xy..., (_wh-_xy)...)
    end
    screen = Screen(w, area=a)
    if applicable(vizzedit, s, screen)
        _s, vis = vizzedit(s, screen)
    else
        vis = visualize(s)
    end

    view(vis, screen)
    cam = screen.cameras[vis.children[][:preferred_camera]]
    center_cam(cam, screen.renderlist)
end
view(visualize(lines))
for i=1:1000
    GLWindow.render_frame(w)
end
Profile.init()
@profile renderloop(w)
Profile.print()
