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

image("fighter1") image("fighter1Bullet")
image("fighter2") image("fighter2Bullet")
image("fighter3") image("fighter3Bullet")

image("bomber1") image("bomber1Bullet")
image("bomber2") image("bomber2Bullet")
image("bomber3") image("bomber3Bullet")

image("minelayer1") image("minelayer1Bullet")
image("minelayer2") image("minelayer2Bullet")
image("minelayer3") image("minelayer3Bullet")

image("commander1") image("commander1Shield")
image("commander1Left") image("commander1LeftDead") image("commander1LeftBullet")
image("commander1Right") image("commander1RightDead") image("commander1RightBullet")
image("commander2") image("commander2Bullet")
image("commander3") image("commander3Shield") image("commander3Bullet")

image("turretBase") image("turretTop") image("turretBullet")

image("flagshipGreebles")

image("glow")
image("normalPowerupContainer")
image("superPowerupContainer")
image("doubleBulletsPowerupSymbol")
image("hyperBeamPowerupSymbol")

image("endingBackground")
image("flagship")
image("explosionWhite")
image("playerFront")

audio("gameStart")
audio("bossEncounter")

audio("enemyHit")
audio("enemyExplosion")
audio("bossExplosion")
audio("shieldHit")
audio("shieldSwap")

audio("playerExplosion")
audio("playerShoot")
audio("powerupAcquired")

audio("flagshipExplosion")

return assets
