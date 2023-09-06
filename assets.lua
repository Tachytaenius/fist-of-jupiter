local assets = {images = {}, audio = {}}

local function image(name)
	assets.images[name] = love.graphics.newImage("assets/images/" .. name .. ".png")
end

local function audio(name, type)
	assets.audio[name] = love.audio.newSource("assets/audio/" .. name .. ".wav", type or "static")
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

image("minelayer1")
image("minelayer2")
image("minelayer3")

image("commander1")
image("commander1Left")
image("commander1LeftDead")
image("commander1Right")
image("commander1RightDead")

image("glow")
image("normalPowerupContainer")
image("superPowerupContainer")
image("doubleBulletsPowerupSymbol")
image("hyperBeamPowerupSymbol")

audio("gameStart")
audio("bossEncounter")
audio("enemyHit")
audio("playerExplosion")

return assets
