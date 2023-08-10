function math.sign(x)
	return x > 0 and 1 or x == 0 and 0 or -1
end
math.tau = math.pi * 2

local vec2 = require("lib.mathsies").vec2
local list = require("lib.list")

local registry = require("registry")

local function randCircle(r)
	return vec2.fromAngle(love.math.random() * math.tau) * r * love.math.random() ^ 0.5
end

local function shallowClone(t)
	local ret = {}
	for k, v in pairs(t) do
		ret[k] = v
	end
	return ret
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
local particlesPerArea = 0.75
local flashAlpha = 0.5
local controls = {
	up = "w",
	down = "s",
	left = "a",
	right = "d",
	shoot = "space"
}

local player, gameState, spareLives, enemies, enemiesToMaterialise, playerBullets, enemyBullets, cameraYOffset, particles, enemyPool, spawnAttemptTimer, spawnAttemptTimerLength, maxEnemies
local minEnemiesToSpawn, maxEnemiesToSpawn
local gameCanvas, canvasScale

local function spawnEnemy(enemy, timer)
	enemy.timeUntilSpawn = timer
	enemiesToMaterialise:add(enemy)
	local newParticleCount = math.floor((math.pi * enemy.radius ^ 2) * particlesPerArea)
	for i = 1, newParticleCount do
		local relPos = randCircle(enemy.radius)
		local vel = relPos * 15
		particles:add({
			pos = relPos + enemy.pos + vel * timer,
			vel = -vel,
			lifetime = timer,
			size = love.math.random() < 0.1 and 2 or 1,
			colour = shallowClone(enemy.colour)
		})
	end
end

local function explode(radius, pos, colour)
	local newParticleCount = math.floor((math.pi * radius ^ 2) * particlesPerArea)
	for i = 1, newParticleCount do
		local relPos = randCircle(radius)
		particles:add({
			pos = relPos + pos,
			vel = relPos * 15,
			lifetime = (love.math.random() / 2 + 0.5) * 0.5,
			size = love.math.random() < 0.1 and 2 or 1,
			colour = shallowClone(colour)
		})
	end
end

local function winWave()
	-- TODO
end

local function initGame()
	player = {
		pos = vec2(gameWidth / 2, 1000),
		vel = vec2(),
		maxSpeedX = 100,
		maxSpeedUp = 200,
		maxSpeedDown = 150,
		accelX = 800,
		accelUp = 1000,
		accelDown = 750,
		maxBullets = 5,
		radius = 6,
		bulletExitOffset = vec2(0, -5),
		health = 1,
		dead = false,
		colour = {0.6, 0.2, 0.2},
		contactInvulnerabilityTimerLength = 1,
		contactInvulnerabilityTimer = nil,
		flashAnimationSpeed = 30
	}
	gameState = "play"
	spareLives = 2
	enemies = list()
	enemiesToMaterialise = list()
	playerBullets = list()
	enemyBullets = list()
	cameraYOffset = 128
	particles = list()

	enemyPool = {
		fighter1 = 8,
		bomber1 = 3
	}
	spawnAttemptTimer = 0.5
	spawnAttemptTimerLength = 0.5
	maxEnemies = 6
	minEnemiesToSpawn = 1
	maxEnemiesToSpawn = 3
end

function love.load()
	initGame()

	canvasScale = 2
	love.window.setMode(gameWidth * canvasScale, gameHeight * canvasScale)
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.graphics.setLineStyle("rough")
	gameCanvas = love.graphics.newCanvas(gameWidth, gameHeight)

	assets = require("assets")
end

function love.keypressed(key)
	if key == controls.shoot then
		if not player.dead and playerBullets.size < player.maxBullets then
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
	if player.health <= 0 and not player.dead then
		player.dead = true
		explode(player.radius, player.pos, player.colour)
	end
	if not player.dead then
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
		
		if not player.contactInvulnerabilityTimer then
			for i = 1, enemies.size do
				local enemy = enemies:get(i)
				if vec2.distance(player.pos, enemy.pos) <= player.radius + enemy.radius then
					player.health = player.health - enemy.contactDamage
					player.contactInvulnerabilityTimer = player.contactInvulnerabilityTimerLength
					break
				end
			end
		else
			player.contactInvulnerabilityTimer = player.contactInvulnerabilityTimer - dt
			if player.contactInvulnerabilityTimer <= 0 then
				player.contactInvulnerabilityTimer = nil
			end
		end
	end
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

	if not player.dead then
		player.pos = player.pos + player.vel * dt
		local cameraSlowdownFactorSameDirection = (cameraYOffsetMax - cameraYOffset) / cameraYOffsetMax
		local cameraSlowdownFactorOppositeDirections = (1 - (cameraYOffsetMax - cameraYOffset) / cameraYOffsetMax)
		local cameraSlowdownFactor = math.sign(player.vel.y) * math.sign(cameraYOffset) == -1 and cameraSlowdownFactorOppositeDirections or cameraSlowdownFactorSameDirection
		cameraYOffset = math.min(cameraYOffsetMax, math.max(-cameraYOffsetMax * 0, cameraYOffset + player.vel.y * dt * cameraSlowdownFactor))
	end

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
		enemy.shootTimer = enemy.shootTimer - dt
		if enemy.shootTimer <= 0 then
			local timerFactor = love.math.random() / 0.5 + 0.75
			enemy.shootTimer = enemy.shootTimerLength * timerFactor
			local posDiff = player.pos - enemy.pos
			if #posDiff > 0 then
				enemyBullets:add({
					pos = enemy.pos,
					vel = enemy.bulletSpeed * vec2.normalise(posDiff),
					radius = enemy.bulletRadius,
					damage = enemy.bulletDamage
				})
			end
		end
	end
	for _, enemy in ipairs(enemiesToDelete) do
		enemies:remove(enemy)
		explode(enemy.radius, enemy.pos, enemy.colour)
	end

	local enemyBulletsToDelete = {}
	for i = 1, enemyBullets.size do
		local enemyBullet = enemyBullets:get(i)
		enemyBullet.pos = enemyBullet.pos + enemyBullet.vel * dt
		if
			enemyBullet.pos.x + enemyBullet.radius <= 0 or enemyBullet.pos.x - enemyBullet.radius >= gameWidth or
			enemyBullet.pos.y - player.pos.y + cameraYOffset + gameHeight / 2 + enemyBullet.radius <= 0 or
			enemyBullet.pos.y - player.pos.y + cameraYOffset + gameHeight / 2 - enemyBullet.radius >= gameHeight
		then
			enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
		elseif not player.dead and vec2.distance(enemyBullet.pos, player.pos) <= player.radius then
			enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
			player.health = player.health - enemyBullet.damage
		end
	end
	for _, enemyBullet in ipairs(enemyBulletsToDelete) do
		enemyBullets:remove(enemyBullet)
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

	local enemiesToSpawn = {}
	for i = 1, enemiesToMaterialise.size do
		local enemy = enemiesToMaterialise:get(i)
		enemy.timeUntilSpawn = enemy.timeUntilSpawn - dt
		if enemy.timeUntilSpawn <= 0 then
			enemy.timeUntilSpawn = nil
			enemiesToSpawn[#enemiesToSpawn+1] = enemy
		end
	end
	for _, enemy in ipairs(enemiesToSpawn) do
		enemiesToMaterialise:remove(enemy)
		enemies:add(enemy)
		if player.pos ~= enemy.pos then
			enemy.vel = enemy.speed * vec2.normalise(player.pos - enemy.pos)
			enemy.vel.y = math.abs(enemy.vel.y)
		else
			enemy.vel = vec2()
		end
	end

	spawnAttemptTimer = spawnAttemptTimer - dt
	if spawnAttemptTimer <= 0 then
		local timerFactor = love.math.random() / 0.5 + 0.75
		spawnAttemptTimer = spawnAttemptTimerLength * timerFactor
		local numberToSpawn = math.max(0, math.min(love.math.random(minEnemiesToSpawn, maxEnemiesToSpawn), maxEnemies - enemies.size))
		for _=1, numberToSpawn do
			local options = {}
			for k, v in pairs(enemyPool) do
				if v > 0 then
					options[#options+1] = k
				end
			end
			if #options == 0 then
				winWave()
				break
			end
			local enemyType = options[love.math.random(#options)]
			enemyPool[enemyType] = enemyPool[enemyType] - 1
			local registryEntry = registry.enemies[enemyType]
			local x = love.math.random() * (gameWidth - borderSize * 2) + borderSize
			local screenTopInWorldSpace = cameraYOffset + player.pos.y - gameHeight
			local y = love.math.random() * gameHeight / 4 + screenTopInWorldSpace
			spawnEnemy({
				pos = vec2(x, y),
				vel = vec2(),
				radius = registryEntry.radius,
				health = registryEntry.health,
				type = enemyType,
				colour = shallowClone(registryEntry.colour),
				speed = registryEntry.speed,
				shootTimerLength = registryEntry.shootTimerLength,
				shootTimer = love.math.random() * 0.5,
				bulletSpeed = registryEntry.bulletSpeed,
				bulletRadius = registryEntry.bulletRadius,
				bulletDamage = registryEntry.bulletDamage,
				contactDamage = registryEntry.contactDamage
			}, registryEntry.materialisationTime)
		end
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
		local asset = assets.images[enemy.type]
		if asset then
			love.graphics.draw(asset, enemy.pos.x - asset:getWidth() / 2, enemy.pos.y - asset:getHeight() / 2)
		else
			love.graphics.circle("fill", enemy.pos.x, enemy.pos.y, enemy.radius)
		end
	end
	love.graphics.setColor(1, 0, 0)
	for i = 1, playerBullets.size do
		local playerBullet = playerBullets:get(i)
		love.graphics.line(playerBullet.pos.x, playerBullet.pos.y + playerBullet.trailLength, playerBullet.pos.x, playerBullet.pos.y)
	end
	love.graphics.setColor(1, 1, 1)
	for i = 1, enemyBullets.size do
		local enemyBullet = enemyBullets:get(i)
		love.graphics.circle("fill", enemyBullet.pos.x, enemyBullet.pos.y, enemyBullet.radius)
	end
	for i = 1, particles.size do
		local particle = particles:get(i)
		love.graphics.setPointSize(particle.size)
		love.graphics.setColor(particle.colour)
		love.graphics.points(particle.pos.x, particle.pos.y)
	end
	love.graphics.setPointSize(1)
	love.graphics.setColor(1, 1, 1)
	if not player.dead then
		local flash = player.contactInvulnerabilityTimer and math.floor(player.contactInvulnerabilityTimer * player.flashAnimationSpeed) % 2 == 0
		if flash then
			love.graphics.setColor(1, 1, 1, flashAlpha)
		end
		love.graphics.draw(assets.images.player, player.pos.x - assets.images.player:getWidth() / 2, player.pos.y - assets.images.player:getHeight() / 2)
		love.graphics.setColor(1, 1, 1)
	end

	love.graphics.origin()
	love.graphics.setCanvas()
	love.graphics.draw(gameCanvas, 0, 0, 0, canvasScale)
end
