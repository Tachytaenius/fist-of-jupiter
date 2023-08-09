local assets = {images = {}}

local function image(name)
	assets.images[name] = love.graphics.newImage("assets/images/" .. name .. ".png")
end

image("player")
image("fighter1")
image("bomber1")

return assets
