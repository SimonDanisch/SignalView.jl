using Reactive, SignalView, GeometryTypes, Colors, GLWindow, GLVisualize, GLAbstraction
import Images

window = glscreen()

# loadasset loads data from the GLVisualize asset folder and is defined as
# FileIO.load(assetpath(name))
doge = Images.restrict(Images.restrict(loadasset("doge.png"))).data

# Convert to RGBA{Float32}. Float for filtering and 32 because it fits the GPU better
img = map(RGB{Float32}, doge)
# create a slider that goes from 1-20 in 0.1 steps
sigma = Signal(1f0)

# performant conversion to RGBAU8, implemted with a functor
# in 0.5 anonymous functions offer the same speed, so this wouldn't be needed
"""
Applies a gaussian filter to `img` and converts it to RGBA{U8}
"""
function gauss(img, sigma)
	Images.imfilter_gaussian(img, [sigma, sigma])
end

function laplacian(img)
    map(RGB{Float32}, Images.imfilter(img, Images.imlaplacian()))
end

function postprocess(img, scale)
    map(img) do color
        scaled = color .* scale
        RGB{Float32}(1f0-scaled.r, 1f0-scaled.g, 1f0-scaled.b)
    end
end
gaussed = map(gauss, Signal(img), sigma)
println("gaussed ", typeof(gaussed))

edges  = map(laplacian, gaussed)
println("edges ", typeof(edges))

dilated = map(postprocess, edges, Signal(4.0f0))
println("dilated ", typeof(dilated))

#pass the signal root to view_signal
view_signal(sigma, window)

renderloop(window)
