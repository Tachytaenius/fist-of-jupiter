function math.sign(x)
	return x > 0 and 1 or x == 0 and 0 or -1
end
math.tau = math.pi * 2

local vec2 = require("lib.mathsies").vec2
local list = require("lib.list")

local function randCircle(r)
	return vec2.fromAngle(love.math.random() * math.tau) * r * love.math.random() ^ 0.5
end

local assets

local gameWidth, gameHeight = 160*2, 144*3
local borderSize = 24
local cameraYOffsetMax = 128
local backgroundScale = 0.75
local backgroundPointDistanceX = gameWidth / 8
local backgroundPointDistanceY = gameWidth / 8
local backgroundPointOffsetX = gameWidth / 16
local backgroundPointOffsetY = gameWidth / 16
local controls = {
	up = "w",
	down = "s",
	left = "a",
	right = "d",
	shoot = "space"
}

local player, gameState, spareLives, enemies, playerBullets, enemyBullets, cameraYOffset, particles
local gameCanvas, canvasScale

function love.load()
	player = {
		pos = vec2(gameWidth / 2, gameHeight - borderSize),
		vel = vec2(),
		maxSpeedX = 100,
		maxSpeedUp = 200,
		maxSpeedDown = 150,
		accelX = 800,
		accelUp = 1000,
		accelDown = 750,
		maxBullets = 5,
		radius = 6,
		bulletExitOffset = vec2(0, -5)
	}
	gameState = "play"
	spareLives = 2
	enemies = list()
	playerBullets = list()
	enemyBullets = list()
	cameraYOffset = 128
	particles = list()

	enemies:add({
		pos = vec2(100, 200),
		vel = vec2(),
		radius = 6,
		health = 1
	})
	enemies:add({
		pos = vec2(200, 200),
		vel = vec2(),
		radius = 10,
		health = 2
	})

	canvasScale = 2
	love.window.setMode(gameWidth * canvasScale, gameHeight * canvasScale)
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.graphics.setLineStyle("rough")
	gameCanvas = love.graphics.newCanvas(gameWidth, gameHeight)

	assets = require("assets")
end

function love.keypressed(key)
	if key == controls.shoot then
		if playerBullets.size < player.maxBullets then
			playerBullets:add({
				vel = vec2(0, -450),
				pos = player.pos + player.bulletExitOffset,
				trailLength = 8,
				damage = 1
			})
		end
	end
end

function love.update(dt)
	-- Player movement x
	local movedX = false
	if love.keyboard.isDown(controls.left) then
		player.vel.x = player.vel.x - player.accelX * dt
		movedX = true
	end
	if love.keyboard.isDown(controls.right) then
		player.vel.x = player.vel.x + player.accelX * dt
		movedX = true
	end
	if not movedX then
		player.vel.x = math.max(0, math.abs(player.vel.x) - player.accelX * dt) * math.sign(player.vel.x)
	end
	player.vel.x = math.max(-player.maxSpeedX, math.min(player.maxSpeedX, player.vel.x))
	-- Player movement y
	local movedY = false
	if love.keyboard.isDown(controls.up) then
		player.vel.y = player.vel.y - player.accelUp * dt
		movedY = true
	end
	if love.keyboard.isDown(controls.down) then
		player.vel.y = player.vel.y + player.accelDown * dt
		movedY = true
	end
	if not movedY then
		if player.vel.y > 0 then
			player.vel.y = math.max(0, player.vel.y - player.accelUp * dt)
		else
			player.vel.y = math.min(0, player.vel.y + player.accelDown * dt)
		end
	end
	player.vel.y = math.max(-player.maxSpeedUp, math.min(player.maxSpeedDown, player.vel.y))
	-- Player movement limiting
	if player.pos.x < borderSize then
		player.pos.x = borderSize
		player.vel.x = math.max(0, player.vel.x)
	elseif player.pos.x > gameWidth - borderSize then
		player.pos.x = gameWidth - borderSize
		player.vel.x = math.min(0, player.vel.x)
	end
	-- if player.pos.y < borderSize then
	-- 	player.pos.y = borderSize
	-- 	player.vel.y = math.max(0, player.vel.y)
	-- elseif player.pos.y > gameHeight - borderSize then
	-- 	player.pos.y = gameHeight - borderSize
	-- 	player.vel.y = math.min(0, player.vel.y)
	-- end

	player.pos = player.pos + player.vel * dt
	local cameraSlowdownFactorSameDirection = (cameraYOffsetMax - cameraYOffset) / cameraYOffsetMax
	local cameraSlowdownFactorOppositeDirections = (1 - (cameraYOffsetMax - cameraYOffset) / cameraYOffsetMax)
	local cameraSlowdownFactor = math.sign(player.vel.y) * math.sign(cameraYOffset) == -1 and cameraSlowdownFactorOppositeDirections or cameraSlowdownFactorSameDirection
	cameraYOffset = math.min(cameraYOffsetMax, math.max(-cameraYOffsetMax * 0, cameraYOffset + player.vel.y * dt * cameraSlowdownFactor))

	local deleteThesePlayerBullets = {}
	for i = 1, playerBullets.size do
		local playerBullet = playerBullets:get(i)
		playerBullet.pos = playerBullet.pos + playerBullet.vel * dt
		if playerBullet.pos.y + playerBullet.trailLength - player.pos.y + cameraYOffset + gameHeight / 2 < 0 then
			deleteThesePlayerBullets[#deleteThesePlayerBullets + 1] = playerBullet
		else
			for j = 1, enemies.size do
				local enemy = enemies:get(j)
				if vec2.distance(enemy.pos, playerBullet.pos) <= enemy.radius then
					deleteThesePlayerBullets[#deleteThesePlayerBullets + 1] = playerBullet
					enemy.health = enemy.health - playerBullet.damage
				end
			end
		end
	end
	for _, playerBullet in ipairs(deleteThesePlayerBullets) do
		playerBullets:remove(playerBullet)
	end

	local enemiesToDelete = {}
	for i = 1, enemies.size do
		local enemy = enemies:get(i)
		if enemy.health <= 0 then
			enemiesToDelete[#enemiesToDelete+1] = enemy
		end
		enemy.pos = enemy.pos + enemy.vel * dt
	end
	for _, enemy in ipairs(enemiesToDelete) do
		enemies:remove(enemy)
		local particlesPerArea = 1
		local newParticleCount = math.floor((math.pi * enemy.radius ^ 2) * particlesPerArea)
		for i = 1, newParticleCount do
			local relPos = randCircle(enemy.radius)
			particles:add({
				pos = relPos + enemy.pos,
				vel = relPos * 15,
				lifetime = (love.math.random() / 2 + 0.5) * 0.5,
				size = love.math.random() < 0.1 and 2 or 1,
				colour = {1, 1, 1}
			})
		end
	end

	for i = 1, enemyBullets.size do
		local enemyBullet = enemyBullets:get(i)
		enemyBullet.pos = enemyBullet.pos + enemyBullet.vel * dt
	end

	local particlesToDelete = {}
	for i = 1, particles.size do
		local particle = particles:get(i)
		particle.pos = particle.pos + particle.vel * dt
		particle.lifetime = particle.lifetime - dt
		if particle.lifetime <= 0 then
			particlesToDelete[#particlesToDelete+1] = particle
		end
	end
	for _, particle in ipairs(particlesToDelete) do
		particles:remove(particle)
	end
end

function love.draw()
	love.graphics.setCanvas(gameCanvas)
	love.graphics.clear()

	love.graphics.translate(-player.pos.x / 4, -player.pos.y / 2)
	love.graphics.translate(0, gameHeight/2)
	love.graphics.translate(0, cameraYOffset / 2)
	for x = -backgroundPointDistanceX * 20, gameWidth + backgroundPointDistanceX * 20, backgroundPointDistanceX do
		x = x + backgroundPointOffsetX
		for y = -backgroundPointDistanceY * 5, gameHeight + backgroundPointDistanceY * 5, backgroundPointDistanceY do
			y = y + backgroundPointOffsetY
			love.graphics.points(
				-- TODO: Add some perspective
				x,
				y
			)
		end
	end
	love.graphics.origin()
	love.graphics.translate(0, -player.pos.y)
	love.graphics.translate(0, gameHeight/2)
	love.graphics.translate(0, cameraYOffset)
	for i = 1, enemies.size do
		local enemy = enemies:get(i)
		love.graphics.circle("fill", enemy.pos.x, enemy.pos.y, enemy.radius)
	end
	for i = 1, playerBullets.size do
		local playerBullet = playerBullets:get(i)
		love.graphics.line(playerBullet.pos.x, playerBullet.pos.y + playerBullet.trailLength, playerBullet.pos.x, playerBullet.pos.y)
	end
	for i = 1, enemyBullets.size do
		local enemyBullet = enemyBullets:get(i)
		love.graphics.circle("fill", enemyBullet.pos.x, enemyBullet.pos.y, 1)
	end
	for i = 1, particles.size do
		local particle = particles:get(i)
		love.graphics.setPointSize(particle.size)
		love.graphics.setColor(particle.colour)
		love.graphics.points(particle.pos.x, particle.pos.y)
	end
	love.graphics.setPointSize(1)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(assets.player, player.pos.x - assets.player:getWidth() / 2, player.pos.y - assets.player:getHeight() / 2)

	love.graphics.origin()
	love.graphics.setCanvas()
	love.graphics.draw(gameCanvas, 0, 0, 0, canvasScale)
end
