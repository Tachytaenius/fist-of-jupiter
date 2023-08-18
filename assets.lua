local assets = {images = {}}

local function image(name)
	assets.images[name] = love.graphics.newImage("assets/images/" .. name .. ".png")
end

image("title")
image("cursor")

image("player")
image("playerThrustersBack")
image("playerThrustersFront")

image("fighter1")
image("fighter2")
image("fighter3")

image("bomber1")
image("bomber2")
image("bomber3")

return assets
