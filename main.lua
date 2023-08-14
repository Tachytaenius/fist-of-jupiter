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

local function normaliseOrZero(v)
	local r = #v
	if r == 0 then
		return vec2()
	end
	return v/r
end

local function shallowClone(t)
	local ret = {}
	for k, v in pairs(t) do
		ret[k] = v
	end
	return ret
end

local function hsv2rgb(h, s, v)
	-- This function doesn't modulo hue by 360 or clamp saturation and value for you
	if s == 0 then
		return v, v, v
	end
	local _h = h / 60
	local i = math.floor(_h)
	local f = _h - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	elseif i == 5 then
		return v, p, q
	end
end

local function marchVectorToTarget(movee, target, speed, dt)
	local moveeRelativeToTarget = movee - target
	local direction = normaliseOrZero(moveeRelativeToTarget)
	local length = #moveeRelativeToTarget
	local newMoveeRelativeToTarget = direction * math.max(0, length - speed * dt)
	return newMoveeRelativeToTarget + target
end

local assets

local gameWidth, gameHeight = 160*2, 144*3

local consts = {
	borderSize = 24,
	cameraYOffsetMax = 128,
	backgroundScale = 0.75,
	backgroundPointDistanceX = gameWidth / 8,
	backgroundPointDistanceY = gameWidth / 8,
	backgroundPointOffsetX = gameWidth / 16,
	backgroundPointOffsetY = gameWidth / 16,
	particlesPerArea = 0.75,
	flashAlpha = 0.5,
	explosionSourceRadiusPerDamage = 1.5,
	bulletHitParticleBounceMultiplier = 0.1,
	titleOptionCount = 2,
	titleOptionsYPos = 256,
	distanceToGenerateBlocks = 2000,
	particleBlockSize = 500,
	permanentStationaryParticlesPerBlock = 20,
	movingParticlesPerBlock = 2,
	movingBlockParticleMaxSpeed = 100,
	movingBackgroundParticleDeletionTime = 2,
	backgroundParticlePointScale = 8,
	maxParticleBlockDistance = 4000,
	titleScreenVelocityChangeTimerLength = 3,
	titleScreenCameraSpeed = 600,
	titleCameraAccel = 1000,
	gameOverTextWaitTimerLength = 1.5,
	preRespawnCentringTimerLength = 0.25,
	postRespawnCentringTimerLength = 0.1,
	respawnCentringSpeed = 100,
	playLikeStates = {
		play = true,
		waveWon = true
	},
	scoreReductionTimerLength = 0.2,
	scoreReductionAmount = 1
}

local controls = {
	up = "w",
	down = "s",
	left = "a",
	right = "d",
	shoot = "space"
}

-- Variables for all states
local backgroundParticleBlockLayers

-- Title variables
local cursorPos, titleCameraPos, titleCameraVelocity, titleCameraTargetVelocity, titleScreenVelocityChangeTimer

-- Play variables
local player, gameState, spareLives, enemies, enemiesToMaterialise, playerBullets, enemyBullets, cameraYOffset, particles, enemyPool, spawnAttemptTimer, spawnAttemptTimerLength, maxEnemies
local gameOverTextWaitTimer, gameOverTextPresent, gameOver, respawnCentringDone, preRespawnCentringTimer, postRespawnCentringTimer, respawnCentringAnimationInProgress, score
local scoreReductionTimer
local minEnemiesToSpawn, maxEnemiesToSpawn

local gameCanvas, canvasScale, font

local function implode(radius, pos, colour, timer, velocityBoost)
	local newParticleCount = math.floor((math.pi * radius ^ 2) * consts.particlesPerArea)
	for i = 1, newParticleCount do
		local relPos = randCircle(radius)
		local vel = relPos * 15 + (velocityBoost or vec2())
		particles:add({
			pos = relPos + pos + vel * timer,
			vel = -vel,
			invisibleTime = timer - (love.math.random() / 2 + 0.5) * 0.5,
			lifetime = timer,
			size = love.math.random() < 0.1 and 2 or 1,
			colour = shallowClone(colour)
		})
	end
end

local function spawnEnemy(enemy, timer)
	enemy.timeUntilSpawn = timer
	enemiesToMaterialise:add(enemy)
	implode(enemy.radius, enemy.pos, enemy.colour, timer)
end

local function explode(radius, pos, colour, velocityBoost, isPlayer)
	velocityBoost = velocityBoost or vec2()
	local newParticleCount = math.floor((math.pi * radius ^ 2) * consts.particlesPerArea)
	for i = 1, newParticleCount do
		local relPos = randCircle(radius)
		particles:add({
			pos = relPos + pos,
			vel = relPos * 15 + velocityBoost,
			lifetime = (love.math.random() / 2 + 0.5) * 0.5,
			size = love.math.random() < 0.1 and 2 or 1,
			colour = shallowClone(colour),
			isPlayer = isPlayer
		})
	end
end

local function winWave()
	gameState = "waveWon"
end

local function circleOffScreen(radius, pos)
	return
		pos.x + radius <= 0 or pos.x - radius >= gameWidth or
		pos.y - player.pos.y + cameraYOffset + gameHeight / 2 + radius <= 0 or
		pos.y - player.pos.y + cameraYOffset + gameHeight / 2 - radius >= gameHeight
end

local function initBackgroundParticles()
	backgroundParticleBlockLayers = {
		{distance = 6, blocks = {}},
		{distance = 5, blocks = {}},
		{distance = 4, blocks = {}},
		{distance = 3, blocks = {}},
		{distance = 2, blocks = {}},
		-- {distance = 1, blocks = {}}
	}
end

local function initTitleState()
	gameState = "title"
	initBackgroundParticles()

	cursorPos = 0
	titleCameraPos = vec2()
	titleCameraVelocity = vec2()
	titleCameraTargetVelocity = nil
	titleScreenVelocityChangeTimer = consts.titleScreenVelocityChangeTimerLength * love.math.random() * 1/2 + 3/4
end

local function isPlayerPresent()
	return not (player.dead or player.spawning)
end

local function generatePlayer()
	local pos
	if player then
		local screenTopInWorldSpace = player.pos.y - gameHeight / 2 - cameraYOffset
		pos = vec2(player.pos.x, screenTopInWorldSpace + gameHeight / 2 + consts.cameraYOffsetMax)
		cameraYOffset = consts.cameraYOffsetMax
	else
		pos = vec2(gameWidth / 2, 0)
	end
	local spawnTime = 0.75
	player = {
		pos = pos,
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
		flashAnimationSpeed = 30,
		spawning = true,
		spawnTimer = spawnTime
	}
	implode(player.radius, player.pos, player.colour, spawnTime)
end

local function initPlayState()
	gameState = "play"
	backgroundParticleBlockLayers = {}

	spareLives = 2
	enemies = list()
	enemiesToMaterialise = list()
	playerBullets = list()
	enemyBullets = list()
	cameraYOffset = consts.cameraYOffsetMax
	particles = list()
	generatePlayer()

	enemyPool = {
		fighter1 = 8,
		bomber1 = 3
	}
	spawnAttemptTimerLength = 0.5
	spawnAttemptTimer = spawnAttemptTimerLength -- Doesn't get used while spawning and gets reset when the player actually spawns
	maxEnemies = 6
	minEnemiesToSpawn = 1
	maxEnemiesToSpawn = 3
	gameOverTextPresent = false
	gameOverTextWaitTimer = nil
	gameOver = false
	preRespawnCentringTimer = nil
	postRespawnCentringTimer = nil
	respawnCentringAnimationInProgress = false
	score = 0
	scoreReductionTimer = consts.scoreReductionTimerLength
end

function love.load()
	initTitleState()

	canvasScale = 2
	love.window.setMode(gameWidth * canvasScale, gameHeight * canvasScale)
	love.window.setTitle("Fist of Jupiter")
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.graphics.setLineStyle("rough")
	gameCanvas = love.graphics.newCanvas(gameWidth, gameHeight)

	assets = require("assets")

	font = love.graphics.newImageFont("assets/images/font.png", " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.!?$,#@~:;-{}&()<>'%/*0123456789")
end

function love.keypressed(key)
	if gameState == "play" then
		if key == controls.shoot then
			if isPlayerPresent() and playerBullets.size < player.maxBullets then
				playerBullets:add({
					vel = vec2(0, -450),
					pos = player.pos + player.bulletExitOffset,
					trailLength = 8,
					damage = 1
				})
			elseif player.dead and gameOverTextPresent then
				initTitleState()
			end
		end
	elseif gameState == "title" then
		if key == controls.up then
			cursorPos = (cursorPos - 1) % consts.titleOptionCount
		elseif key == controls.down then
			cursorPos = (cursorPos + 1) % consts.titleOptionCount
		elseif key == controls.shoot then
			if cursorPos == 0 then
				initPlayState()
			elseif cursorPos == 1 then
				
			end
		end
	end
end

function love.update(dt)
	if backgroundParticleBlockLayers then
		local function addMovingParticleToBlock(block, layer, x, y)
			block.movingParticles:add({
				pos = consts.particleBlockSize * vec2(love.math.random() + x, love.math.random() + y),
				vel = randCircle(consts.movingBlockParticleMaxSpeed),
				size = consts.backgroundParticlePointScale / layer.distance,
				deletionTimer = consts.movingBackgroundParticleDeletionTime * (love.math.random() * 1/2 + 3/4),
				colour = {hsv2rgb(love.math.random() * 360, 1, 0.75 * math.min(1, 3/layer.distance))},
				-- colour = {0.5 * math.min(1, 3/layer.distance), 0, 0}
				-- colour = {hsv2rgb(((love.math.random() * 2 - 1) * 30) % 360, 1, 0.75 * math.min(1, 3/layer.distance))}
			})
		end
		local cameraPos = gameState == "title" and titleCameraPos or consts.playLikeStates[gameState] and player.pos
		for _, layer in ipairs(backgroundParticleBlockLayers) do
			-- Add needed blocks
			local minXWorldSpace = cameraPos.x - consts.distanceToGenerateBlocks + gameWidth / 2
			local maxXWorldSpace = cameraPos.x + consts.distanceToGenerateBlocks + gameWidth / 2
			local minYWorldSpace = cameraPos.y - consts.distanceToGenerateBlocks + gameHeight / 2
			local maxYWorldSpace = cameraPos.y + consts.distanceToGenerateBlocks + gameHeight / 2
			for x = math.floor(minXWorldSpace / consts.particleBlockSize), math.ceil(maxXWorldSpace / consts.particleBlockSize) do
				for y = math.floor(minYWorldSpace / consts.particleBlockSize), math.ceil(maxYWorldSpace / consts.particleBlockSize) do
					local blocksX = layer.blocks[x]
					if not blocksX then
						blocksX = {}
						layer.blocks[x] = blocksX
					end
					if not blocksX[y] then
						local newBlock = {
							permanentStationaryParticles = list(),
							movingParticles = list()
						}
						blocksX[y] = newBlock
						for i = 1, consts.permanentStationaryParticlesPerBlock do
							newBlock.permanentStationaryParticles:add({
								pos = consts.particleBlockSize * vec2(love.math.random() + x, love.math.random() + y),
								vel = vec2(),
								size = consts.backgroundParticlePointScale / layer.distance,
								-- colour = {hsv2rgb(love.math.random() * 360, 1, 0.75 * math.min(1, 3/layer.distance))}
								-- colour = {0.5 * math.min(1, 3/layer.distance), 0, 0}
								colour = {hsv2rgb(((love.math.random() * 2 - 1) * 30) % 360, 1, 0.75 * math.min(1, 3/layer.distance))}
							})
						end
						for i = 1, consts.movingParticlesPerBlock do
							addMovingParticleToBlock(newBlock, layer, x, y)
						end
					end
				end
			end
			-- Prune distant blocks
			for x, blocksX in pairs(layer.blocks) do
				if x * consts.particleBlockSize - cameraPos.x > consts.maxParticleBlockDistance then -- maybe the cameraPos.x part technically needs to have gameWidth / 2 added
					layer.blocks[x] = nil
				else
					for y, blocksY in pairs(blocksX) do
						if y * consts.particleBlockSize - cameraPos.y > consts.maxParticleBlockDistance then
							blocksX[y] = nil
						end
					end
					local hasBlocks = false
					for y, blocksY in pairs(blocksX) do
						hasBlocks = true
						break
					end
					if not hasBlocks then
						layer.blocks[x] = nil
					end
				end
			end
			-- Update moving particles
			for x, blocksX in pairs(layer.blocks) do
				for y, block in pairs(blocksX) do
					local particlesToDelete = {}
					for i = 1, block.movingParticles.size do
						local particle = block.movingParticles:get(i)
						particle.pos = particle.pos + particle.vel * dt
						particle.deletionTimer = particle.deletionTimer - dt
						if particle.deletionTimer <= 0 then
							particlesToDelete[#particlesToDelete+1] = particle
						end
					end
					for _, particle in ipairs(particlesToDelete) do
						block.movingParticles:remove(particle)
					end
					for _=1, consts.movingParticlesPerBlock - block.movingParticles.size do
						addMovingParticleToBlock(block, layer, x, y)
					end
				end
			end
		end
	end
	if gameState == "title" then
		local function newTargetVel()
			local targetSpeed = consts.titleScreenCameraSpeed -- Do I want to randomise this?
			titleCameraTargetVelocity = vec2.fromAngle(love.math.random() * math.tau) * targetSpeed * (love.math.random() / 2 + 3/4)
		end
		if not titleCameraTargetVelocity then
			-- Just entered state
			newTargetVel()
			titleCameraVelocity = titleCameraTargetVelocity
		end

		titleScreenVelocityChangeTimer = titleScreenVelocityChangeTimer - dt
		if titleScreenVelocityChangeTimer <= 0 then
			titleScreenVelocityChangeTimer = consts.titleScreenVelocityChangeTimerLength * (love.math.random() * 1/2 + 3/4)
			newTargetVel()
		end

		titleCameraVelocity = marchVectorToTarget(titleCameraVelocity, titleCameraTargetVelocity, consts.titleCameraAccel, dt)
		titleCameraPos = titleCameraPos + titleCameraVelocity * dt
	elseif consts.playLikeStates[gameState] then
		if player.spawning then
			player.spawnTimer = player.spawnTimer - dt
			if player.spawnTimer <= 0 then
				player.spawning = false
				player.spawnTimer = nil
				spawnAttemptTimer = spawnAttemptTimerLength
			end
		end

		if player.health <= 0 and not player.dead then
			player.dead = true
			explode(player.radius, player.pos, player.colour, vec2(), true)
			if spareLives == 0 then
				gameOver = true
			else
				preRespawnCentringTimer = consts.preRespawnCentringTimerLength
			end
			spareLives = math.max(0, spareLives - 1)
		end
		if isPlayerPresent() then
			-- Player movement x
			local movedX = false
			if gameState == "play" and love.keyboard.isDown(controls.left) then
				player.vel.x = player.vel.x - player.accelX * dt
				movedX = true
			end
			if gameState == "play" and love.keyboard.isDown(controls.right) then
				player.vel.x = player.vel.x + player.accelX * dt
				if movedX then
					movedX = false
				else
					movedX = true
				end
			end
			if not movedX then
				player.vel.x = math.max(0, math.abs(player.vel.x) - player.accelX * dt) * math.sign(player.vel.x)
			end
			player.vel.x = math.max(-player.maxSpeedX, math.min(player.maxSpeedX, player.vel.x))
			-- Player movement y
			local movedY = false
			if gameState == "play" and love.keyboard.isDown(controls.up) then
				player.vel.y = player.vel.y - player.accelUp * dt
				movedY = true
			end
			if gameState == "play" and love.keyboard.isDown(controls.down) then
				player.vel.y = player.vel.y + player.accelDown * dt
				if movedY then
					movedY = false
				else
					movedY = true
				end
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
						if player.health > 0 then
							explode(enemy.contactDamage * consts.explosionSourceRadiusPerDamage, player.pos + normaliseOrZero(enemy.pos - player.pos) * player.radius, shallowClone(player.colour))
						end
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

		if isPlayerPresent() then
			player.pos = player.pos + player.vel * dt
			local cameraSlowdownFactorSameDirection = (consts.cameraYOffsetMax - cameraYOffset) / consts.cameraYOffsetMax
			local cameraSlowdownFactorOppositeDirections = (1 - (consts.cameraYOffsetMax - cameraYOffset) / consts.cameraYOffsetMax)
			local cameraSlowdownFactor = math.sign(player.vel.y) * math.sign(cameraYOffset) == -1 and cameraSlowdownFactorOppositeDirections or cameraSlowdownFactorSameDirection
			cameraYOffset = math.min(consts.cameraYOffsetMax, math.max(-consts.cameraYOffsetMax * 0, cameraYOffset + player.vel.y * dt * cameraSlowdownFactor))
		end

		-- Player movement limiting
		if player.pos.x < consts.borderSize then
			player.pos.x = consts.borderSize
			player.vel.x = math.max(0, player.vel.x)
		elseif player.pos.x > gameWidth - consts.borderSize then
			player.pos.x = gameWidth - consts.borderSize
			player.vel.x = math.min(0, player.vel.x)
		end
		-- if player.pos.y < consts.borderSize then
		-- 	player.pos.y = consts.borderSize
		-- 	player.vel.y = math.max(0, player.vel.y)
		-- elseif player.pos.y > gameHeight - consts.borderSize then
		-- 	player.pos.y = gameHeight - consts.borderSize
		-- 	player.vel.y = math.min(0, player.vel.y)
		-- end

		if gameOver then
			if not gameOverTextPresent then
				if gameOverTextWaitTimer then
					gameOverTextWaitTimer = gameOverTextWaitTimer - dt
					if gameOverTextWaitTimer <= 0 then
						gameOverTextPresent = true
					end
				-- elseif enemyBullets.size == 0 and enemiesToMaterialise.size == 0 and enemies.size == 0 then
				else
					gameOverTextWaitTimer = consts.gameOverTextWaitTimerLength
				end
			end
		elseif player.dead then
			-- Not game over but we're dead, make enemies go away quickly for another round
			local screenTopInWorldSpace = player.pos.y - gameHeight / 2 - cameraYOffset
			for i = 1, enemies.size do
				-- There are nicer ways to do this, I'm sure, and I had one in mind but didn't bother to execute it for some reason
				local enemy = enemies:get(i)
				local topDist = math.abs(screenTopInWorldSpace - enemy.pos.y)
				local bottomDist = math.abs(screenTopInWorldSpace + gameHeight - enemy.pos.y)
				-- local leftDist = math.abs(0 - enemy.pos.x)
				local leftDist = enemy.pos.x
				local rightDist = math.abs(gameWidth - enemy.pos.x)
				local topOverBottom = topDist < bottomDist
				local leftOverRight = leftDist < rightDist
				local dir
				if topOverBottom then
					if leftOverRight then
						if topDist < leftDist then
							dir = vec2(0, -1)
						else
							dir = vec2(-1, 0)
						end
					else
						if topDist < rightDist then
							dir = vec2(0, -1)
						else
							dir = vec2(1, 0)
						end
					end
				else
					if leftOverRight then
						if bottomDist < leftDist then
							dir = vec2(0, 1)
						else
							dir = vec2(-1, 0)
						end
					else
						if bottomDist < rightDist then
							dir = vec2(0, 1)
						else
							dir = vec2(1, 0)
						end
					end
				end
				enemy.targetVel = dir * enemy.speed
			end

			if preRespawnCentringTimer then
				preRespawnCentringTimer = preRespawnCentringTimer - dt
				if preRespawnCentringTimer <= 0 then
					preRespawnCentringTimer = nil
					respawnCentringAnimationInProgress = true
				end
			end
			if respawnCentringAnimationInProgress then
				if player.pos.x > gameWidth / 2 then
					player.pos.x = math.max(gameWidth / 2, player.pos.x - consts.respawnCentringSpeed * dt)
				else
					player.pos.x = math.min(gameWidth / 2, player.pos.x + consts.respawnCentringSpeed * dt)
				end
				if player.pos.x == gameWidth / 2 then
					respawnCentringAnimationInProgress = false
					postRespawnCentringTimer = consts.postRespawnCentringTimerLength
				end
			end
			if postRespawnCentringTimer then
				postRespawnCentringTimer = postRespawnCentringTimer - dt
				if postRespawnCentringTimer <= 0 then
					postRespawnCentringTimer = nil
				end
			end
			local allCentringFinished = not preRespawnCentringTimer and player.pos.x == gameWidth / 2 and not postRespawnCentringTimer

			local noPlayerParticlesLeft = true
			for i = 1, particles.size do
				local particle = particles:get(i)
				if particle.isPlayer then
					noPlayerParticlesLeft = false
					break
				end
			end

			if enemyBullets.size == 0 and enemiesToMaterialise.size == 0 and enemies.size == 0 and allCentringFinished and noPlayerParticlesLeft then
				generatePlayer()
			end
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
						if enemy.health > 0 then
							explode(playerBullet.damage * consts.explosionSourceRadiusPerDamage, playerBullet.pos, shallowClone(enemy.colour), -playerBullet.vel * consts.bulletHitParticleBounceMultiplier)
						end
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
				explode(enemy.radius, enemy.pos, enemy.colour)
				score = score + enemy.defeatScore
			elseif circleOffScreen(enemy.radius, enemy.pos) then
				enemiesToDelete[#enemiesToDelete+1] = enemy
				enemyPool[enemy.type] = enemyPool[enemy.type] + 1 -- Let the enemy come back
			end
			enemy.vel = marchVectorToTarget(enemy.vel, enemy.targetVel, enemy.accel, dt)
			enemy.pos = enemy.pos + enemy.vel * dt
			if isPlayerPresent() then
				enemy.shootTimer = enemy.shootTimer - dt
				if enemy.shootTimer <= 0 then
					local timerFactor = love.math.random() / 0.5 + 0.75
					enemy.shootTimer = enemy.shootTimerLength * timerFactor
					local posDiff = player.pos - enemy.pos
					if #posDiff > 0 then
						for i = 0, enemy.bulletCount - 1 do
							local angleOffset = enemy.bulletCount == 1 and 0 or (i / (enemy.bulletCount - 1) - 0.5) * enemy.bulletSpreadAngle
							enemyBullets:add({
								pos = enemy.pos,
								vel = enemy.bulletSpeed * vec2.rotate(vec2.normalise(posDiff), angleOffset),
								radius = enemy.bulletRadius,
								damage = enemy.bulletDamage
							})
						end
					end
				end
			end
		end
		for _, enemy in ipairs(enemiesToDelete) do
			enemies:remove(enemy)
		end

		local enemyBulletsToDelete = {}
		for i = 1, enemyBullets.size do
			local enemyBullet = enemyBullets:get(i)
			enemyBullet.pos = enemyBullet.pos + enemyBullet.vel * dt
			if circleOffScreen(enemyBullet.radius, enemyBullet.pos) then
				enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
			elseif isPlayerPresent() and vec2.distance(enemyBullet.pos, player.pos) <= player.radius then
				enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
				player.health = player.health - enemyBullet.damage
				if player.health > 0 then
					explode(enemyBullet.damage * consts.explosionSourceRadiusPerDamage, enemyBullet.pos, shallowClone(player.colour), -enemyBullet.vel * consts.bulletHitParticleBounceMultiplier, true)
				end
			end
		end
		for _, enemyBullet in ipairs(enemyBulletsToDelete) do
			enemyBullets:remove(enemyBullet)
		end

		local particlesToDelete = {}
		for i = 1, particles.size do
			local particle = particles:get(i)
			particle.pos = particle.pos + particle.vel * dt
			if particle.invisibleTime then
				particle.invisibleTime = particle.invisibleTime - dt
				if particle.invisibleTime <= 0 then
					particle.invisibleTime = nil
				end
			end
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
				-- enemy.vel = enemy.speed * vec2.normalise(player.pos - enemy.pos)
				-- enemy.vel.y = math.abs(enemy.vel.y)
				enemy.targetVel = enemy.speed * vec2.normalise(player.pos - enemy.pos)
				enemy.targetVel.y = math.abs(enemy.targetVel.y)
			else
				enemy.vel = vec2()
			end
		end

		spawnAttemptTimer = spawnAttemptTimer - dt
		if spawnAttemptTimer <= 0 then
			local timerFactor = love.math.random() / 0.5 + 0.75
			spawnAttemptTimer = spawnAttemptTimerLength * timerFactor
			local numberToSpawn = not isPlayerPresent() and 0 or math.max(0, math.min(love.math.random(minEnemiesToSpawn, maxEnemiesToSpawn), maxEnemies - enemies.size))
			for _=1, numberToSpawn do
				local options = {}
				for k, v in pairs(enemyPool) do
					if v > 0 then
						options[#options+1] = k
					end
				end
				if #options == 0 then
					break
				end
				local enemyType = options[love.math.random(#options)]
				enemyPool[enemyType] = enemyPool[enemyType] - 1
				local registryEntry = registry.enemies[enemyType]
				local x = love.math.random() * (gameWidth - consts.borderSize * 2) + consts.borderSize
				local screenTopInWorldSpace = player.pos.y - gameHeight / 2 - cameraYOffset
				local y = love.math.random() * gameHeight / 4 + screenTopInWorldSpace
				spawnEnemy({
					pos = vec2(x, y),
					vel = vec2(),
					targetVel = vec2(),
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
					bulletCount = registryEntry.bulletCount,
					bulletSpreadAngle = registryEntry.bulletSpreadAngle,
					contactDamage = registryEntry.contactDamage,
					defeatScore = registryEntry.defeatScore,
					accel = registryEntry.accel
				}, registryEntry.materialisationTime)
			end
		end

		local enemyPoolIsEmpty = true
		for k, v in pairs(enemyPool) do
			if v > 0 then
				enemyPoolIsEmpty = false
				break
			end
		end
		if enemies.size == 0 and enemiesToMaterialise.size == 0 and enemyBullets.size == 0 and enemyPoolIsEmpty then
			winWave()
		end

		if gameState == "play" and isPlayerPresent() then
			scoreReductionTimer = scoreReductionTimer - dt
			if scoreReductionTimer <= 0 then
				scoreReductionTimer = consts.scoreReductionTimerLength
				score = math.max(0, score - consts.scoreReductionAmount)
			end
		end
	end
end

function love.draw()
	love.graphics.setFont(font)
	love.graphics.setCanvas(gameCanvas)
	love.graphics.clear()

	if backgroundParticleBlockLayers then
		local cameraPos = gameState == "title" and titleCameraPos or consts.playLikeStates[gameState] and player.pos
		for _, layer in ipairs(backgroundParticleBlockLayers) do
			love.graphics.push()
			love.graphics.translate(gameWidth / 2, gameHeight / 2)
			love.graphics.scale(1 / layer.distance)
			love.graphics.translate(-cameraPos.x, -cameraPos.y)
			for x, blocksX in pairs(layer.blocks) do
				for y, block in pairs(blocksX) do
					for j = 1, block.permanentStationaryParticles.size do
						local particle = block.permanentStationaryParticles:get(j)
						love.graphics.setPointSize(particle.size)
						love.graphics.setColor(particle.colour)
						love.graphics.points(particle.pos.x, particle.pos.y)
					end
					for j = 1, block.movingParticles.size do
						local particle = block.movingParticles:get(j)
						love.graphics.setPointSize(particle.size)
						love.graphics.setColor(particle.colour)
						love.graphics.points(particle.pos.x, particle.pos.y)
					end
				end
			end
			love.graphics.pop()
		end
		love.graphics.setPointSize(1)
		love.graphics.setColor(1, 1, 1)
		love.graphics.origin()
	end

	if gameState == "title" then
		love.graphics.draw(assets.images.title)

		local texts = {
			"PLAY",
			"SCORES"
		}
		local textWidth = 0
		for i, v in ipairs(texts) do
			textWidth = math.max(textWidth, font:getWidth(v))
		end
		love.graphics.translate(gameWidth / 2 - textWidth / 2, consts.titleOptionsYPos)
		love.graphics.draw(assets.images.cursor, 0, font:getHeight() * cursorPos + font:getHeight() / 2 - assets.images.cursor:getHeight() / 2)
		love.graphics.translate(assets.images.cursor:getWidth(), 0)
		for i, v in ipairs(texts) do
			love.graphics.print(v, 0, font:getHeight() * (i-1))
		end
	elseif consts.playLikeStates[gameState] then
		love.graphics.translate(-player.pos.x / 4, -player.pos.y / 2)
		love.graphics.translate(0, gameHeight/2)
		love.graphics.translate(0, cameraYOffset / 2)
		for x = -consts.backgroundPointDistanceX * 20, gameWidth + consts.backgroundPointDistanceX * 20, consts.backgroundPointDistanceX do
			x = x + consts.backgroundPointOffsetX
			for y = -consts.backgroundPointDistanceY * 5, gameHeight + consts.backgroundPointDistanceY * 5, consts.backgroundPointDistanceY do
				y = y + consts.backgroundPointOffsetY
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
			if not particle.invisibleTime then
				love.graphics.setPointSize(particle.size)
				love.graphics.setColor(particle.colour)
				love.graphics.points(particle.pos.x, particle.pos.y)
			end
		end
		love.graphics.setPointSize(1)
		love.graphics.setColor(1, 1, 1)
		if isPlayerPresent() then
			local flash = player.contactInvulnerabilityTimer and math.floor(player.contactInvulnerabilityTimer * player.flashAnimationSpeed) % 2 == 0
			if flash then
				love.graphics.setColor(1, 1, 1, consts.flashAlpha)
			end
			love.graphics.draw(assets.images.player, player.pos.x - assets.images.player:getWidth() / 2, player.pos.y - assets.images.player:getHeight() / 2)
			love.graphics.setColor(1, 1, 1)
		end

		love.graphics.origin()

		for i = 1, spareLives do
			love.graphics.draw(assets.images.player, gameWidth - i * assets.images.player:getWidth(), 0)
		end

		if gameOverTextPresent then
			local text = "GAME OVER"
			love.graphics.print(text, gameWidth / 2 - font:getWidth(text) / 2, gameHeight / 2 - font:getHeight() / 2)
		end

		love.graphics.print("SCORE: " .. score, 0, 0)
	end

	love.graphics.origin()
	love.graphics.setCanvas()
	love.graphics.draw(gameCanvas, 0, 0, 0, canvasScale)
end
