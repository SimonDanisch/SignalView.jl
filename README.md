# SignalView

This library lets you visualize the signal graph of [Reactive](https://github.com/JuliaLang/Reactive.jl)'s signals.

It's using [GLVisualize](http://www.glvisualize.com/) for the visualization and [GraphLayout](https://github.com/IainNZ/GraphLayout.jl) to layout the signal graph.

You can interactively edit some nodes like colors and numbers.

TODO:
Interactively edit the graph layout and let user resize and annotate nodes.

# API

```Julia
# create any kind of signal graph
using Reactive, SignalView, GLVisualize
a = Signal(2)
b = Signal(1)
c = map(+, a, b)
# view it
window = glscreen()
# any signal in the graph will do, since both parents and children will get pushed into graph recursevely
view_signal(a, window)
renderloop(window)
```

# Examples


#### Image Processing

![Image Processing](https://github.com/SimonDanisch/SignalView.jl/blob/master/docs/image_proc.png?raw=true)

[video](https://vimeo.com/157136166)
[code](https://github.com/SimonDanisch/SignalView.jl/blob/master/examples/imageproc.jl)


#### Surface / Contour

![Surface / Contour](https://github.com/SimonDanisch/SignalView.jl/blob/master/docs/signalview.png?raw=true)

[video](https://vimeo.com/157128992)
[code](https://github.com/SimonDanisch/SignalView.jl/blob/master/examples/simple.jl)
