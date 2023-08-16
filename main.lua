function math.sign(x)
	return x > 0 and 1 or x == 0 and 0 or -1
end
function math.lerp(a, b, i)
	return a + (b - a) * i
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
	distanceToGenerateBlocksForDistance1 = math.max(gameWidth, gameHeight),
	particleBlockSize = 500,
	permanentStationaryParticlesPerBlock = 20,
	movingParticlesPerBlock = 2,
	movingBlockParticleMaxSpeed = 200,
	movingBackgroundParticleDeletionTime = 2,
	backgroundParticlePointScale = 8,
	maxParticleBlockDistanceForDistance1 = math.max(gameWidth, gameHeight) + 100,
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
	waveWonDelayBeforeResultsScreenTimerLength = 1.5,
	defaultAutoShootTime = 0.5,
	finalNonBossWave = 19,
	bonusScoreTimerLength = 90,
	bonusScoreTimerScorePerSecondLeft = 2,
	killScoreBonusPerCurrentKillStreakOnKill = 3,
	scoreTextTimerLength = 0.5,
	playBackgroundParticleAnimationFrequency = 0.5,
	playBackgroundParticleAnimationAmplitude = 20,
	playBackgroundParticleTimeOffsetPerDistance = 10,
	pauseFlashTimerLength = 1,
	backThrusterQuads = nil,
	frontThrusterQuads = nil,
	backThrusterAnimationFrequency = 10,
	frontThrusterAnimationFrequency = 20
}

local controls = {
	up = "w",
	down = "s",
	left = "a",
	right = "d",
	shoot = "space",
	pause = "escape"
}

local gameState, paused, pauseFlashTimer

-- Variables for all states
local backgroundParticleBlockLayers

local titleVars, playVars

local gameCanvas, canvasScale, font

local function implode(radius, pos, colour, timer, velocityBoost)
	local newParticleCount = math.floor((math.pi * radius ^ 2) * consts.particlesPerArea)
	for i = 1, newParticleCount do
		local relPos = randCircle(radius)
		local vel = relPos * 15 + (velocityBoost or vec2())
		playVars.particles:add({
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
	playVars.enemiesToMaterialise:add(enemy)
	implode(enemy.radius, enemy.pos, enemy.colour, timer)
end

local function explode(radius, pos, colour, velocityBoost, isPlayer)
	velocityBoost = velocityBoost or vec2()
	local newParticleCount = math.floor((math.pi * radius ^ 2) * consts.particlesPerArea)
	for i = 1, newParticleCount do
		local relPos = randCircle(radius)
		playVars.particles:add({
			pos = relPos + pos,
			vel = relPos * 15 + velocityBoost,
			lifetime = (love.math.random() / 2 + 0.5) * 0.5,
			size = love.math.random() < 0.1 and 2 or 1,
			colour = shallowClone(colour),
			isPlayer = isPlayer
		})
	end
	local timerLength = 1.5
	-- playVars.rippleSources:add({
	-- 	pos = vec2.clone(pos),
	-- 	force = radius * 10,
	-- 	timer = timerLength,
	-- 	timerLength = timerLength,
	-- 	amplitude = 10,
	-- 	frequency = 2,
	-- 	phasePerDistance = 0.1
	-- })
end

local function checkAllEnemiesDefeatedAndEnemyBulletsGone()
	local enemyPoolIsEmpty = true
	for k, v in pairs(playVars.enemyPool) do
		if v > 0 then
			enemyPoolIsEmpty = false
			break
		end
	end
	return
		playVars.enemies.size == 0 and
		playVars.enemiesToMaterialise.size == 0 and
		playVars.enemyBullets.size == 0 and
		enemyPoolIsEmpty
end

local function givePowerup(name)
	if name == "hyperBeam" then
		local timerLength = 10
		playVars.player.powerups.hyperBeam = {
			shootTimerLength = 0.01,
			timer = timerLength,
			timerLength = timerLength,
			hueCycleSpeed = 30
		}
	elseif name == "doubleBullets" then
		-- Also stops your bullets from resetting kill streak if they miss
		local timerLength = 12.5
		playVars.player.powerups.doubleBullets = {
			timer = timerLength,
			timerLength = timerLength
		}
	end
end

local function generatePlayer(resetPos)
	local pos
	if not resetPos and playVars.player then
		local screenTopInWorldSpace = playVars.player.pos.y - gameHeight / 2 - playVars.cameraYOffset
		pos = vec2(playVars.player.pos.x, screenTopInWorldSpace + gameHeight / 2 + consts.cameraYOffsetMax)
	else
		pos = vec2(gameWidth / 2, 0)
	end
	playVars.cameraYOffset = consts.cameraYOffsetMax
	local spawnTime = 0.75
	playVars.player = {
		pos = pos,
		vel = vec2(),
		maxSpeedX = 100,
		maxSpeedUp = 200,
		maxSpeedDown = 150,
		accelX = 800,
		accelUp = 1000,
		accelDown = 750,
		maxbulletCostBeforeShooting = 5,
		radius = 6,
		bulletExitOffset = vec2(0, -4),
		health = 4,
		dead = false,
		colour = {0.6, 0.2, 0.2},
		contactInvulnerabilityTimerLength = 1,
		contactInvulnerabilityTimer = nil,
		flashAnimationSpeed = 30,
		spawning = true,
		spawnTimer = spawnTime,
		powerups = {},
		killStreak = 0
	}
	implode(playVars.player.radius, playVars.player.pos, playVars.player.colour, spawnTime)
end

local function nextWave()
	gameState = "play"
	playVars.waveNumber = (playVars.waveNumber or 0) + 1
	playVars.resultsScreenVars = nil
	playVars.onResultsScreen = false
	playVars.waveScore = 0
	playVars.bonusTimer = consts.bonusScoreTimerLength

	backgroundParticleBlockLayers = {
		{distance = 7, blocks = {}, style = "play"},
		{distance = 6, blocks = {}, style = "play"},
		{distance = 5, blocks = {}, style = "play"},
		{distance = 4, blocks = {}, style = "play"}
	}

	playVars.enemies = list()
	playVars.enemiesToMaterialise = list()
	playVars.playerBullets = list()
	playVars.enemyBullets = list()
	playVars.particles = list()
	playVars.floatingTexts = list()
	playVars.rippleSources = list()
	generatePlayer(true)

	playVars.enemyPool = {}
	for k, v in pairs(registry.enemies) do
		playVars.enemyPool[k] = math.floor(v.count(playVars.waveNumber))
	end
	local lerpFactor = (playVars.waveNumber - 1) / (consts.finalNonBossWave - 1)
	playVars.spawnAttemptTimerLength = math.lerp(1, 0.25, lerpFactor)
	playVars.spawnAttemptTimer = playVars.spawnAttemptTimerLength -- Doesn't get used while spawning and gets reset when the player actually spawns
	playVars.maxEnemies = math.floor(math.lerp(4, 10, lerpFactor))
	playVars.minEnemiesToSpawn = math.floor(math.lerp(2, 3, lerpFactor))
	playVars.maxEnemiesToSpawn = math.floor(math.lerp(3, 6, lerpFactor))
end

local function winWave()
	gameState = "waveWon"
	playVars.waveWonDelayBeforeResultsScreenTimer = consts.waveWonDelayBeforeResultsScreenTimerLength
end

local function circleOffScreen(radius, pos)
	return
		pos.x + radius <= 0 or pos.x - radius >= gameWidth or
		pos.y - playVars.player.pos.y + playVars.cameraYOffset + gameHeight / 2 + radius <= 0 or
		pos.y - playVars.player.pos.y + playVars.cameraYOffset + gameHeight / 2 - radius >= gameHeight
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
	titleVars = {}
	initBackgroundParticles()

	titleVars.cursorPos = 0
	titleVars.titleCameraPos = vec2()
	titleVars.titleCameraVelocity = vec2()
	titleVars.titleCameraTargetVelocity = nil
	titleVars.titleScreenVelocityChangeTimer = consts.titleScreenVelocityChangeTimerLength * love.math.random() * 1/2 + 3/4
end

local function isPlayerPresent()
	return not (playVars.player.dead or playVars.player.spawning)
end

local function initPlayState()
	gameState = "play"

	playVars = {}

	playVars.spareLives = 4
	playVars.cameraYOffset = consts.cameraYOffsetMax
	playVars.time = 0
	playVars.gameOverTextPresent = false
	playVars.gameOverTextWaitTimer = nil
	playVars.gameOver = false
	playVars.preRespawnCentringTimer = nil
	playVars.postRespawnCentringTimer = nil
	playVars.respawnCentringAnimationInProgress = false
	playVars.totalScore = 0
	playVars.scoreTimerReductionAmount = 1
	playVars.scoreBoostPerLifeAtWaveWon = 10 -- You may go through lots of waves with the same number of lives, which would be an excessive advantage, hence the low value

	nextWave()
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
	consts.backThrusterQuads = {
		love.graphics.newQuad(0, 0, 16, 16, 16, 64),
		love.graphics.newQuad(0, 16, 16, 16, 16, 64),
		love.graphics.newQuad(0, 32, 16, 16, 16, 64),
		love.graphics.newQuad(0, 48, 16, 16, 16, 64)
	}
	consts.frontThrusterQuads = {
		love.graphics.newQuad(0, 0, 16, 16, 16, 32),
		love.graphics.newQuad(0, 16, 16, 16, 16, 32)
	}
end

local function getPlayerBulletsCostUsed()
	local use = 0
	for i = 1, playVars.playerBullets.size do
		use = use + playVars.playerBullets:get(i).cost
	end
	return use
end

local function shootBullet()
	if checkAllEnemiesDefeatedAndEnemyBulletsGone() then
		return
	end
	local double = playVars.player.powerups.doubleBullets
	local num = double and 2 or 1
	for i = 1, num do
		local shotWidth = playVars.player.radius - 3
		local xOffset = num == 1 and 0 or ((i - 1) / (num - 1) - 0.5) * shotWidth
		local newBullet = {
			vel = vec2(0, -450),
				pos = playVars.player.pos + playVars.player.bulletExitOffset + vec2(xOffset, 0),
			trailLength = 8,
			damage = 1,
			colour = {1, 0, 0},
			lineSize = 1,
				cost = double and 0.5 or 1,
				missingResetsKillStreak = not double
		}
		if playVars.player.powerups.hyperBeam then
				local hue = (
					playVars.player.powerups.hyperBeam.timer /
					playVars.player.powerups.hyperBeam.timerLength *
					playVars.player.powerups.hyperBeam.hueCycleSpeed -- +
					-- (i - 1) / num -- not (num - 1) -- this introduces an optical illusion that ruins the effect, it no longer looks like two rainbows but two solid colours (for two beams at least)
				) % 1 * 360
			local freshness = playVars.player.powerups.hyperBeam.timer / playVars.player.powerups.hyperBeam.timerLength
			local saturation = (freshness ^ 0.5) * 0.75 + 0.25
			local value = freshness ^ 0.5 * 0.5 + 0.5
			newBullet.colour = {hsv2rgb(hue, saturation, value)}
			newBullet.trailLength = 16
			newBullet.vel = vec2(0, -1000)
			newBullet.damage = 0.25
			newBullet.cost = 0
			newBullet.lineSize = 2
			newBullet.missingResetsKillStreak = false
		end
		playVars.playerBullets:add(newBullet)
	end
end

local function getPlayerShootingType()
	if playVars.player.powerups.hyperBeam then
		return "auto"
	end
	return "semiAuto"
end

function love.keypressed(key)
	if key == controls.pause then
		paused = not paused
		if gameState ~= "play" then
			paused = false
		end
		if paused then
			pauseFlashTimer = 0
		end
	elseif not paused then
		if gameState == "play" then
			if key == controls.shoot then
				if isPlayerPresent() and getPlayerBulletsCostUsed() < playVars.player.maxbulletCostBeforeShooting and getPlayerShootingType() == "semiAuto" then
					shootBullet()
				elseif playVars.player.dead and playVars.gameOverTextPresent then
					initTitleState()
				end
			end
		elseif gameState == "title" then
			if key == controls.up then
				titleVars.cursorPos = (titleVars.cursorPos - 1) % consts.titleOptionCount
			elseif key == controls.down then
				titleVars.cursorPos = (titleVars.cursorPos + 1) % consts.titleOptionCount
			elseif key == controls.shoot then
				if titleVars.cursorPos == 0 then
					initPlayState()
				elseif titleVars.cursorPos == 1 then
					
				end
			end
		elseif gameState == "waveWon" and playVars.onResultsScreen then
			if key == controls.shoot then
				nextWave()
			end
		end
	end
end

function love.update(dt)
	if gameState ~= "play" then
		paused = false
	end
	if paused then
		pauseFlashTimer = (pauseFlashTimer + dt) % consts.pauseFlashTimerLength
		return
	end
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
		local cameraPos = gameState == "title" and titleVars.titleCameraPos or consts.playLikeStates[gameState] and playVars.player.pos
		for _, layer in ipairs(backgroundParticleBlockLayers) do
			-- Add needed blocks
			local minXWorldSpace = cameraPos.x - consts.distanceToGenerateBlocksForDistance1 * layer.distance + gameWidth / 2
			local maxXWorldSpace = cameraPos.x + consts.distanceToGenerateBlocksForDistance1 * layer.distance + gameWidth / 2
			local minYWorldSpace = cameraPos.y - consts.distanceToGenerateBlocksForDistance1 * layer.distance + gameHeight / 2
			local maxYWorldSpace = cameraPos.y + consts.distanceToGenerateBlocksForDistance1 * layer.distance + gameHeight / 2
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
						for i = 1, (layer.style == "play" and 0.5 or 1) * consts.permanentStationaryParticlesPerBlock do
							newBlock.permanentStationaryParticles:add({
								pos = consts.particleBlockSize * vec2(love.math.random() + x, love.math.random() + y),
								vel = vec2(),
								size = consts.backgroundParticlePointScale / layer.distance,
								-- colour = {hsv2rgb(love.math.random() * 360, 1, 0.75 * math.min(1, 3/layer.distance))}
								-- colour = {0.5 * math.min(1, 3/layer.distance), 0, 0}
								colour = layer.style == "play" and 
									{hsv2rgb(((love.math.random() * 2 - 1) * 15 + (playVars.waveNumber - 1) / (consts.finalNonBossWave + 1 - 1) * 360) % 360, 0.5, 0.75 * math.min(1, 3/layer.distance))} or
									{hsv2rgb(((love.math.random() * 2 - 1) * 30) % 360, 1, 0.75 * math.min(1, 3/layer.distance))}
							})
						end
						for i = 1, (layer.style == "play" and 0.5 or 1) * consts.movingParticlesPerBlock do
							addMovingParticleToBlock(newBlock, layer, x, y)
						end
					end
				end
			end
			-- Prune distant blocks
			for x, blocksX in pairs(layer.blocks) do
				if x * consts.particleBlockSize - cameraPos.x > consts.maxParticleBlockDistanceForDistance1 * layer.distance then -- maybe the cameraPos.x part technically needs to have gameWidth / 2 added
					layer.blocks[x] = nil
				else
					for y, blocksY in pairs(blocksX) do
						if y * consts.particleBlockSize - cameraPos.y > consts.maxParticleBlockDistanceForDistance1 * layer.distance then
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
					for _=1, (layer.style == "play" and 0.5 or 1) * consts.movingParticlesPerBlock - block.movingParticles.size do
						addMovingParticleToBlock(block, layer, x, y)
					end
				end
			end
		end
	end
	if gameState == "title" then
		local function newTargetVel()
			local targetSpeed = consts.titleScreenCameraSpeed
			titleVars.titleCameraTargetVelocity = vec2.fromAngle(love.math.random() * math.tau) * targetSpeed * (love.math.random() / 2 + 3/4)
		end
		if not titleVars.titleCameraTargetVelocity then
			-- Just entered state
			newTargetVel()
			-- titleVars.titleCameraVelocity = titleVars.titleCameraTargetVelocity
		end

		titleVars.titleScreenVelocityChangeTimer = titleVars.titleScreenVelocityChangeTimer - dt
		if titleVars.titleScreenVelocityChangeTimer <= 0 then
			titleVars.titleScreenVelocityChangeTimer = consts.titleScreenVelocityChangeTimerLength * (love.math.random() * 1/2 + 3/4)
			newTargetVel()
		end

		titleVars.titleCameraVelocity = marchVectorToTarget(titleVars.titleCameraVelocity, titleVars.titleCameraTargetVelocity, consts.titleCameraAccel, dt)
		titleVars.titleCameraPos = titleVars.titleCameraPos + titleVars.titleCameraVelocity * dt
	elseif consts.playLikeStates[gameState] then
		playVars.time = playVars.time + dt

		playVars.player.fireBackThrusters = false
		playVars.player.fireFrontThrusters = false

		if playVars.player.spawning then
			playVars.player.spawnTimer = playVars.player.spawnTimer - dt
			if playVars.player.spawnTimer <= 0 then
				playVars.player.spawning = false
				playVars.player.spawnTimer = nil
				playVars.spawnAttemptTimer = playVars.spawnAttemptTimerLength
			end
		end

		if playVars.player.health <= 0 and not playVars.player.dead then
			playVars.player.dead = true
			explode(playVars.player.radius, playVars.player.pos, playVars.player.colour, vec2(), true)
			if playVars.spareLives == 0 then
				playVars.gameOver = true
			else
				playVars.preRespawnCentringTimer = consts.preRespawnCentringTimerLength
			end
			playVars.spareLives = math.max(0, playVars.spareLives - 1)
		end
		if isPlayerPresent() then
			local allowMovement = not checkAllEnemiesDefeatedAndEnemyBulletsGone() and gameState == "play"
			-- player movement x
			local dvx = 0
			if allowMovement and love.keyboard.isDown(controls.left) then
				dvx = dvx - playVars.player.accelX * dt
			end
			if allowMovement and love.keyboard.isDown(controls.right) then
				dvx = dvx + playVars.player.accelX * dt
			end
			playVars.player.vel.x = playVars.player.vel.x + dvx
			if dvx == 0 then
				playVars.player.vel.x = math.max(0, math.abs(playVars.player.vel.x) - playVars.player.accelX * dt) * math.sign(playVars.player.vel.x)
			end
			playVars.player.vel.x = math.max(-playVars.player.maxSpeedX, math.min(playVars.player.maxSpeedX, playVars.player.vel.x))
			-- player movement y
			local dvy = 0
			if allowMovement and love.keyboard.isDown(controls.up) then
				dvy = dvy - playVars.player.accelUp * dt
				playVars.player.fireBackThrusters = true
			end
			if allowMovement and love.keyboard.isDown(controls.down) then
				dvy = dvy + playVars.player.accelDown * dt
				playVars.player.fireFrontThrusters = true
			end
			playVars.player.vel.y = playVars.player.vel.y + dvy
			if dvy == 0 then
				if playVars.player.vel.y > 0 then
					playVars.player.vel.y = math.max(0, playVars.player.vel.y - playVars.player.accelUp * dt)
				else
					playVars.player.vel.y = math.min(0, playVars.player.vel.y + playVars.player.accelDown * dt)
				end
			end
			playVars.player.vel.y = math.max(-playVars.player.maxSpeedUp, math.min(playVars.player.maxSpeedDown, playVars.player.vel.y))
			
			if not playVars.player.contactInvulnerabilityTimer then
				for i = 1, playVars.enemies.size do
					local enemy = playVars.enemies:get(i)
					if vec2.distance(playVars.player.pos, enemy.pos) <= playVars.player.radius + enemy.radius then
						playVars.player.health = playVars.player.health - enemy.contactDamage
						if playVars.player.health > 0 then
							explode(enemy.contactDamage * consts.explosionSourceRadiusPerDamage, playVars.player.pos + normaliseOrZero(enemy.pos - playVars.player.pos) * playVars.player.radius, shallowClone(playVars.player.colour))
						end
						playVars.player.contactInvulnerabilityTimer = playVars.player.contactInvulnerabilityTimerLength
						break
					end
				end
			else
				playVars.player.contactInvulnerabilityTimer = playVars.player.contactInvulnerabilityTimer - dt
				if playVars.player.contactInvulnerabilityTimer <= 0 then
					playVars.player.contactInvulnerabilityTimer = nil
				end
			end
		end

		if isPlayerPresent() then
			playVars.player.pos = playVars.player.pos + playVars.player.vel * dt
			local cameraSlowdownFactorSameDirection = (consts.cameraYOffsetMax - playVars.cameraYOffset) / consts.cameraYOffsetMax
			local cameraSlowdownFactorOppositeDirections = (1 - (consts.cameraYOffsetMax - playVars.cameraYOffset) / consts.cameraYOffsetMax)
			local cameraSlowdownFactor = math.sign(playVars.player.vel.y) * math.sign(playVars.cameraYOffset) == -1 and cameraSlowdownFactorOppositeDirections or cameraSlowdownFactorSameDirection
			playVars.cameraYOffset = math.min(consts.cameraYOffsetMax, math.max(-consts.cameraYOffsetMax * 0, playVars.cameraYOffset + playVars.player.vel.y * dt * cameraSlowdownFactor))
		end

		if getPlayerShootingType() ~= "auto" then
			playVars.player.autoShootTimer = nil
		end
		if not playVars.player.autoShootTimer and getPlayerShootingType() == "auto" then
			playVars.player.autoShootTimer = 0
		end
		if isPlayerPresent() then
			if getPlayerShootingType() == "auto" then
				playVars.player.autoShootTimer = math.max(0, playVars.player.autoShootTimer - dt)
				if playVars.player.autoShootTimer <= 0 and love.keyboard.isDown(controls.shoot) then
					local minShootTime = math.huge
					for k, v in pairs(playVars.player.powerups) do
						if v.shootTimerLength then
							minShootTime = math.min(minShootTime, v.shootTimerLength)
						end
					end
					playVars.player.autoShootTimer = minShootTime ~= math.huge and minShootTime or consts.defaultAutoShootTime
					shootBullet()
				end
			end
		end

		if isPlayerPresent() then
			for k, v in pairs(playVars.player.powerups) do
				v.timer = v.timer - dt
				if v.timer <= 0 then
					playVars.player.powerups[k] = nil
				end
			end
		end

		-- player movement limiting
		if playVars.player.pos.x < consts.borderSize then
			playVars.player.pos.x = consts.borderSize
			playVars.player.vel.x = math.max(0, playVars.player.vel.x)
		elseif playVars.player.pos.x > gameWidth - consts.borderSize then
			playVars.player.pos.x = gameWidth - consts.borderSize
			playVars.player.vel.x = math.min(0, playVars.player.vel.x)
		end
		-- if playVars.player.pos.y < consts.borderSize then
		-- 	playVars.player.pos.y = consts.borderSize
		-- 	playVars.player.vel.y = math.max(0, playVars.player.vel.y)
		-- elseif playVars.player.pos.y > gameHeight - consts.borderSize then
		-- 	playVars.player.pos.y = gameHeight - consts.borderSize
		-- 	playVars.player.vel.y = math.min(0, playVars.player.vel.y)
		-- end

		if playVars.gameOver then
			if playVars.playerBullets.size == 0 then -- Let the score loss of bullets missing and player dying all accumulate before calculating gameOverTotalScore
				if not playVars.gameOverTextPresent then
					if playVars.gameOverTextWaitTimer then
						if playVars.playerBullets.size == 0 then
							playVars.gameOverTextWaitTimer = playVars.gameOverTextWaitTimer - dt
							if playVars.gameOverTextWaitTimer <= 0 then
								playVars.gameOverTextPresent = true
								playVars.gameOverTotalScore = playVars.totalScore + playVars.waveScore
							end
						end
					-- elseif playVars.enemyBullets.size == 0 and playVars.enemiesToMaterialise.size == 0 and playVars.enemies.size == 0 then
					else
						playVars.gameOverTextWaitTimer = consts.gameOverTextWaitTimerLength
					end
				end
			end
		elseif playVars.player.dead then
			-- Not game over but we're dead, make playVars.enemies go away quickly for another round
			local screenTopInWorldSpace = playVars.player.pos.y - gameHeight / 2 - playVars.cameraYOffset
			for i = 1, playVars.enemies.size do
				-- There are nicer ways to do this, I'm sure, and I had one in mind but didn't bother to execute it for some reason
				local enemy = playVars.enemies:get(i)
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

			if playVars.preRespawnCentringTimer then
				playVars.preRespawnCentringTimer = playVars.preRespawnCentringTimer - dt
				if playVars.preRespawnCentringTimer <= 0 then
					playVars.preRespawnCentringTimer = nil
					playVars.respawnCentringAnimationInProgress = true
				end
			end
			if playVars.respawnCentringAnimationInProgress then
				if playVars.player.pos.x > gameWidth / 2 then
					playVars.player.pos.x = math.max(gameWidth / 2, playVars.player.pos.x - consts.respawnCentringSpeed * dt)
				else
					playVars.player.pos.x = math.min(gameWidth / 2, playVars.player.pos.x + consts.respawnCentringSpeed * dt)
				end
				if playVars.player.pos.x == gameWidth / 2 then
					playVars.respawnCentringAnimationInProgress = false
					playVars.postRespawnCentringTimer = consts.postRespawnCentringTimerLength
				end
			end
			if playVars.postRespawnCentringTimer then
				playVars.postRespawnCentringTimer = playVars.postRespawnCentringTimer - dt
				if playVars.postRespawnCentringTimer <= 0 then
					playVars.postRespawnCentringTimer = nil
				end
			end
			local allCentringFinished = not playVars.preRespawnCentringTimer and playVars.player.pos.x == gameWidth / 2 and not playVars.postRespawnCentringTimer

			local noPlayerParticlesLeft = true
			for i = 1, playVars.particles.size do
				local particle = playVars.particles:get(i)
				if particle.isPlayer then
					noPlayerParticlesLeft = false
					break
				end
			end

			if playVars.enemyBullets.size == 0 and playVars.enemiesToMaterialise.size == 0 and playVars.enemies.size == 0 and allCentringFinished and noPlayerParticlesLeft then
				generatePlayer()
			end
		end

		local deleteThesePlayerBullets = {}
		for i = 1, playVars.playerBullets.size do
			local playerBullet = playVars.playerBullets:get(i)
			playerBullet.pos = playerBullet.pos + playerBullet.vel * dt
			if playerBullet.pos.y + playerBullet.trailLength - playVars.player.pos.y + playVars.cameraYOffset + gameHeight / 2 < 0 then
				deleteThesePlayerBullets[#deleteThesePlayerBullets + 1] = playerBullet
				if playerBullet.missingResetsKillStreak then
					playVars.player.killStreak = 0
				end
			else
				for j = 1, playVars.enemies.size do
					local enemy = playVars.enemies:get(j)
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
			playVars.playerBullets:remove(playerBullet)
		end

		local enemiesToDelete = {}
		for i = 1, playVars.enemies.size do
			local enemy = playVars.enemies:get(i)
			if enemy.health <= 0 then
				enemiesToDelete[#enemiesToDelete+1] = enemy
				explode(enemy.radius, enemy.pos, enemy.colour)
				if isPlayerPresent() then
					local scoreAdd = enemy.defeatScore + playVars.player.killStreak * consts.killScoreBonusPerCurrentKillStreakOnKill
					playVars.waveScore = playVars.waveScore + scoreAdd
					playVars.floatingTexts:add({
						value = scoreAdd,
						pos = vec2.clone(enemy.pos),
						vel = vec2(0, -20),
						timer = consts.scoreTextTimerLength
					})
					playVars.player.killStreak = playVars.player.killStreak + 1
				end
			elseif circleOffScreen(enemy.radius, enemy.pos) then
				enemiesToDelete[#enemiesToDelete+1] = enemy
				playVars.enemyPool[enemy.type] = playVars.enemyPool[enemy.type] + 1 -- Let the enemy come back
			end
			enemy.vel = marchVectorToTarget(enemy.vel, enemy.targetVel, enemy.accel, dt)
			enemy.pos = enemy.pos + enemy.vel * dt
			if isPlayerPresent() then
				enemy.shootTimer = enemy.shootTimer - dt
				if enemy.shootTimer <= 0 then
					local timerFactor = love.math.random() / 0.5 + 0.75
					enemy.shootTimer = enemy.shootTimerLength * timerFactor
					local posDiff = playVars.player.pos - enemy.pos
					if #posDiff > 0 then
						for i = 0, enemy.bulletCount - 1 do
							local angleOffset = enemy.bulletCount == 1 and 0 or (i / (enemy.bulletCount - 1) - 0.5) * enemy.bulletSpreadAngle
							playVars.enemyBullets:add({
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
			playVars.enemies:remove(enemy)
		end

		local enemyBulletsToDelete = {}
		for i = 1, playVars.enemyBullets.size do
			local enemyBullet = playVars.enemyBullets:get(i)
			enemyBullet.pos = enemyBullet.pos + enemyBullet.vel * dt
			if circleOffScreen(enemyBullet.radius, enemyBullet.pos) then
				enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
			elseif isPlayerPresent() and vec2.distance(enemyBullet.pos, playVars.player.pos) <= playVars.player.radius then
				enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
				playVars.player.health = playVars.player.health - enemyBullet.damage
				if playVars.player.health > 0 then
					explode(enemyBullet.damage * consts.explosionSourceRadiusPerDamage, enemyBullet.pos, shallowClone(playVars.player.colour), -enemyBullet.vel * consts.bulletHitParticleBounceMultiplier, true)
				end
			end
		end
		for _, enemyBullet in ipairs(enemyBulletsToDelete) do
			playVars.enemyBullets:remove(enemyBullet)
		end

		local particlesToDelete = {}
		for i = 1, playVars.particles.size do
			local particle = playVars.particles:get(i)
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
			playVars.particles:remove(particle)
		end

		local enemiesToSpawn = {}
		for i = 1, playVars.enemiesToMaterialise.size do
			local enemy = playVars.enemiesToMaterialise:get(i)
			enemy.timeUntilSpawn = enemy.timeUntilSpawn - dt
			if enemy.timeUntilSpawn <= 0 then
				enemy.timeUntilSpawn = nil
				enemiesToSpawn[#enemiesToSpawn+1] = enemy
			end
		end
		for _, enemy in ipairs(enemiesToSpawn) do
			playVars.enemiesToMaterialise:remove(enemy)
			playVars.enemies:add(enemy)
			if playVars.player.pos ~= enemy.pos then
				-- enemy.vel = enemy.speed * vec2.normalise(playVars.player.pos - enemy.pos)
				-- enemy.vel.y = math.abs(enemy.vel.y)
				enemy.targetVel = enemy.speed * vec2.normalise(playVars.player.pos - enemy.pos)
				enemy.targetVel.y = math.abs(enemy.targetVel.y)
			else
				enemy.vel = vec2()
			end
		end

		playVars.spawnAttemptTimer = playVars.spawnAttemptTimer - dt
		if playVars.spawnAttemptTimer <= 0 then
			local timerFactor = love.math.random() / 0.5 + 0.75
			playVars.spawnAttemptTimer = playVars.spawnAttemptTimerLength * timerFactor
			local numberToSpawn = not isPlayerPresent() and 0 or math.max(0, math.min(love.math.random(playVars.minEnemiesToSpawn, playVars.maxEnemiesToSpawn), playVars.maxEnemies - playVars.enemies.size))
			for _=1, numberToSpawn do
				local options = {}
				for k, v in pairs(playVars.enemyPool) do
					if v > 0 then
						options[#options+1] = k
					end
				end
				if #options == 0 then
					break
				end
				local enemyType = options[love.math.random(#options)]
				playVars.enemyPool[enemyType] = playVars.enemyPool[enemyType] - 1
				local registryEntry = registry.enemies[enemyType]
				local x = love.math.random() * (gameWidth - consts.borderSize * 2) + consts.borderSize
				local screenTopInWorldSpace = playVars.player.pos.y - gameHeight / 2 - playVars.cameraYOffset
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
					accel = registryEntry.accel,
					creationTime = playVars.time -- For consistent draw sorting
				}, registryEntry.materialisationTime)
			end
		end

		local textsToDelete = {}
		for i = 1, playVars.floatingTexts.size do
			local text = playVars.floatingTexts:get(i)
			text.pos = text.pos + text.vel * dt
			text.timer = text.timer - dt
			if text.timer <= 0 then
				textsToDelete[#textsToDelete+1] = text
			end
		end
		for _, text in ipairs(textsToDelete) do
			playVars.floatingTexts:remove(text)
		end

		local ripplesToDelete = {}
		for i = 1, playVars.rippleSources.size do
			local ripple = playVars.rippleSources:get(i)
			ripple.timer = ripple.timer - dt
			if ripple.timer <= 0 then
				ripplesToDelete[#ripplesToDelete+1] = ripple
			end
		end
		for _, ripple in ipairs(ripplesToDelete) do
			playVars.rippleSources:remove(ripple)
		end

		if
			gameState == "play" and
			checkAllEnemiesDefeatedAndEnemyBulletsGone() and
			playVars.playerBullets.size == 0 and
			isPlayerPresent()
		then
			winWave()
		end

		-- if gameState == "play" and isPlayerPresent() and not checkAllEnemiesDefeatedAndEnemyBulletsGone() then
		-- 	playVars.scoreReductionTimer = playVars.scoreReductionTimer - dt
		-- 	if playVars.scoreReductionTimer <= 0 then
		-- 		playVars.scoreReductionTimer = playVars.scoreReductionTimerLength
		-- 		playVars.waveScore = math.max(0, playVars.waveScore - playVars.scoreTimerReductionAmount)
		-- 	end
		-- end

		if gameState == "play" and isPlayerPresent() and not checkAllEnemiesDefeatedAndEnemyBulletsGone() then
			playVars.bonusTimer = math.max(0, playVars.bonusTimer - dt)
		end

		if gameState == "waveWon" then
			if playVars.waveWonDelayBeforeResultsScreenTimer then
				playVars.waveWonDelayBeforeResultsScreenTimer = playVars.waveWonDelayBeforeResultsScreenTimer - dt
				if playVars.waveWonDelayBeforeResultsScreenTimer <= 0 then
					playVars.waveWonDelayBeforeResultsScreenTimer = nil
					playVars.onResultsScreen = true
					playVars.resultsScreenVars = {}
					playVars.resultsScreenVars.prevTotalScore = playVars.totalScore
					local lifeBonus = playVars.spareLives * playVars.scoreBoostPerLifeAtWaveWon
					playVars.resultsScreenVars.lifeBonus = lifeBonus
					local timeBonus = math.ceil(playVars.bonusTimer * consts.bonusScoreTimerScorePerSecondLeft)
					playVars.resultsScreenVars.timeBonus = timeBonus
					playVars.totalScore = playVars.totalScore + playVars.waveScore + lifeBonus + timeBonus
				end
			end
		end
	end
end

function love.draw()
	love.graphics.setFont(font)

	if paused then
		if pauseFlashTimer / consts.pauseFlashTimerLength < 0.5 then
			love.graphics.setColor(0.5, 0.5, 0.5)
		else
			love.graphics.setColor(1, 1, 1)
		end
		love.graphics.draw(gameCanvas, 0, 0, 0, canvasScale)
		return
	end

	love.graphics.setCanvas(gameCanvas)
	love.graphics.clear()

	if backgroundParticleBlockLayers and not (playVars and playVars.onResultsScreen) then
		local cameraPos = gameState == "title" and titleVars.titleCameraPos or consts.playLikeStates[gameState] and (playVars.player.pos * vec2(0, 1))
		for i, layer in ipairs(backgroundParticleBlockLayers) do
			love.graphics.push()
			love.graphics.translate(gameWidth / 2, gameHeight / 2)
			love.graphics.scale(1 / layer.distance)
			if consts.playLikeStates[gameState] then
				love.graphics.translate(0, playVars.cameraYOffset)
			end
			love.graphics.translate(-cameraPos.x, -cameraPos.y)
			for x, blocksX in pairs(layer.blocks) do
				for y, block in pairs(blocksX) do
					for j = 1, block.permanentStationaryParticles.size do
						local particle = block.permanentStationaryParticles:get(j)
						love.graphics.setPointSize(particle.size)
						love.graphics.setColor(particle.colour)
						local offset = vec2()
						if consts.playLikeStates[gameState] then
							for i = 1, playVars.rippleSources.size do
								local ripple = playVars.rippleSources:get(i)

								local skew = 2
								local height = 1
								local powExp = 2

								local timeZeroToOne = 1 - ripple.timer / ripple.timerLength
								local bent = timeZeroToOne ^ (1 / skew)
								local properRange = 2 * bent - 1
								local powOut = properRange ^ powExp
								
								local timeFactor = height * (1 - powOut)

								local dist = math.sqrt(
									(particle.pos.x - ripple.pos.x) ^ 2 +
									(particle.pos.y - ripple.pos.y) ^ 2 +
									(50 * (layer.distance - 0)) ^ 2
								)
								local distTimeFactor = timeFactor * math.min(1, (dist / 50) ^ -1)
								local pushFactor = ripple.force * distTimeFactor +
									distTimeFactor * ripple.amplitude * math.sin(
										(ripple.timerLength - ripple.timer) * ripple.frequency * math.tau +
										dist * ripple.phasePerDistance
									) / 2 + 1
								offset = offset + pushFactor * normaliseOrZero(particle.pos - ripple.pos)
							end
							offset.y = offset.y + math.sin(
								(playVars.time * consts.playBackgroundParticleAnimationFrequency) * math.tau +
								particle.pos.x * consts.playBackgroundParticleTimeOffsetPerDistance +
								particle.pos.y * consts.playBackgroundParticleTimeOffsetPerDistance
							) * consts.playBackgroundParticleAnimationAmplitude
						end
						love.graphics.points(particle.pos.x + offset.x - gameWidth / 2, particle.pos.y + offset.y)
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
		love.graphics.draw(assets.images.cursor, 0, font:getHeight() * titleVars.cursorPos + font:getHeight() / 2 - assets.images.cursor:getHeight() / 2)
		love.graphics.translate(assets.images.cursor:getWidth(), 0)
		for i, v in ipairs(texts) do
			love.graphics.print(v, 0, font:getHeight() * (i-1))
		end
	elseif consts.playLikeStates[gameState] then
		if gameState == "waveWon" and playVars.onResultsScreen then
			love.graphics.origin()
			local texts = {
				"PREV. TOTAL: " .. playVars.resultsScreenVars.prevTotalScore,
				"WAVE SCORE: " .. playVars.waveScore,
				"LIFE BONUS: " .. playVars.resultsScreenVars.lifeBonus,
				"TIME BONUS: " .. playVars.resultsScreenVars.timeBonus,
				"TOTAL SCORE: " .. playVars.totalScore
			}
			local textHeight = font:getHeight() * #texts
			love.graphics.translate(0, gameHeight / 2 - textHeight / 2)
			for i, v in ipairs(texts) do
				love.graphics.print(v, gameWidth / 2 - font:getWidth(v) / 2, font:getHeight() * (i- 1))
			end
		else
			love.graphics.translate(0, -playVars.player.pos.y / 4)
			love.graphics.translate(0, gameHeight/2)
			love.graphics.translate(0, playVars.cameraYOffset / 2)
			for x = -consts.backgroundPointDistanceX * 20, gameWidth + consts.backgroundPointDistanceX * 20, consts.backgroundPointDistanceX do
				x = x + consts.backgroundPointOffsetX
				for y = -consts.backgroundPointDistanceY * 5, gameHeight + consts.backgroundPointDistanceY * 5, consts.backgroundPointDistanceY do
					y = y + consts.backgroundPointOffsetY
					-- love.graphics.points(
					-- 	-- TODO: Add some perspective
					-- 	x,
					-- 	y
					-- )
				end
			end
			love.graphics.origin()
			love.graphics.translate(0, -playVars.player.pos.y)
			love.graphics.translate(0, gameHeight/2)
			love.graphics.translate(0, playVars.cameraYOffset)
			local enemiesToDraw = {}
			for i = 1, playVars.enemies.size do
				local enemy = playVars.enemies:get(i)
				enemiesToDraw[#enemiesToDraw+1] = enemy
			end
			table.sort(enemiesToDraw, function(a, b) return a.creationTime < b.creationTime end)
			for _, enemy in ipairs(enemiesToDraw) do
				local asset = assets.images[enemy.type]
				if asset then
					love.graphics.draw(asset, enemy.pos.x - asset:getWidth() / 2, enemy.pos.y - asset:getHeight() / 2)
				else
					love.graphics.circle("fill", enemy.pos.x, enemy.pos.y, enemy.radius)
				end
			end
			for i = 1, playVars.playerBullets.size do
				local playerBullet = playVars.playerBullets:get(i)
				love.graphics.setColor(playerBullet.colour)
				love.graphics.setLineWidth(playerBullet.lineSize)
				love.graphics.line(playerBullet.pos.x, playerBullet.pos.y + playerBullet.trailLength, playerBullet.pos.x, playerBullet.pos.y)
			end
			love.graphics.setLineWidth(1)
			love.graphics.setColor(1, 1, 1)
			for i = 1, playVars.enemyBullets.size do
				local enemyBullet = playVars.enemyBullets:get(i)
				love.graphics.circle("fill", enemyBullet.pos.x, enemyBullet.pos.y, enemyBullet.radius)
			end
			for i = 1, playVars.particles.size do
				local particle = playVars.particles:get(i)
				if not particle.invisibleTime then
					love.graphics.setPointSize(particle.size)
					love.graphics.setColor(particle.colour)
					love.graphics.points(particle.pos.x, particle.pos.y)
				end
			end
			love.graphics.setPointSize(1)
			love.graphics.setColor(1, 1, 1)
			if isPlayerPresent() then
				if playVars.player.fireBackThrusters then
					local quad = consts.backThrusterQuads[math.floor((playVars.time * consts.backThrusterAnimationFrequency) % 1 * 4) + 1]
					love.graphics.draw(assets.images.playerThrustersBack, quad, playVars.player.pos.x - assets.images.player:getWidth() / 2, playVars.player.pos.y + assets.images.player:getHeight() / 2)
				end
				if playVars.player.fireFrontThrusters then
					local quad = consts.frontThrusterQuads[math.floor((playVars.time * consts.frontThrusterAnimationFrequency) % 1 * 2) + 1]
					love.graphics.draw(assets.images.playerThrustersFront, quad, playVars.player.pos.x - assets.images.player:getWidth() / 2, playVars.player.pos.y - assets.images.player:getHeight() / 2)
				end
				local flash = playVars.player.contactInvulnerabilityTimer and math.floor(playVars.player.contactInvulnerabilityTimer * playVars.player.flashAnimationSpeed) % 2 == 0
				if flash then
					love.graphics.setColor(1, 1, 1, consts.flashAlpha)
				end
				love.graphics.draw(assets.images.player, playVars.player.pos.x - assets.images.player:getWidth() / 2, playVars.player.pos.y - assets.images.player:getHeight() / 2)
				love.graphics.setColor(1, 1, 1)
			end

			if not playVars.gameOverTextPresent then
				for i = 1, playVars.floatingTexts.size do
					local floatingText = playVars.floatingTexts:get(i)
					local width = font:getWidth(floatingText.value)
					love.graphics.print(floatingText.value, floatingText.pos.x - width / 2, floatingText.pos.y - font:getHeight() / 2)
				end
			end

			love.graphics.origin()

			for i = 1, playVars.spareLives do
				love.graphics.draw(assets.images.player, gameWidth - i * assets.images.player:getWidth(), 0)
			end

			if playVars.gameOverTextPresent then
				local gameOverText = "GAME OVER"
				local totalScoreText = "TOTAL SCORE: " .. playVars.gameOverTotalScore
				love.graphics.print(gameOverText, gameWidth / 2 - font:getWidth(gameOverText) / 2, gameHeight / 2 - font:getHeight())
				love.graphics.print(totalScoreText, gameWidth / 2 - font:getWidth(totalScoreText) / 2, gameHeight / 2)
			end

			love.graphics.print(playVars.totalScore, 1, 0)
			love.graphics.print(playVars.waveScore, 1, font:getHeight())
		end
	end

	love.graphics.origin()
	love.graphics.setCanvas()
	love.graphics.draw(gameCanvas, 0, 0, 0, canvasScale)
end
