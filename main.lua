local versionWithLineBreak = love.filesystem.read("version.txt") -- This file is provided on build
local version = versionWithLineBreak and versionWithLineBreak:gsub("\n", "") or "unknown"

-- It's known that if you quit while all opposition are defeated but a powerup is on screen (i.e. before results screen),
-- your score record will say quitWhileAllOppositionDefeated but you won't get the life bonus or time bonus

function math.sign(x)
	return x > 0 and 1 or x == 0 and 0 or -1
end
function math.lerp(a, b, i)
	return a + (b - a) * i
end
function math.round(x)
	return math.floor(x + 0.5)
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

local borderSize = 32
local consts = {
	borderSize = borderSize,
	cameraYOffsetMax = gameHeight / 2 - borderSize,
	backgroundScale = 0.75,
	backgroundPointDistanceX = gameWidth / 8,
	backgroundPointDistanceY = gameWidth / 8,
	backgroundPointOffsetX = gameWidth / 16,
	backgroundPointOffsetY = gameWidth / 16,
	particlesPerArea = 0.75,
	flashAlpha = 0.5,
	explosionSourceRadiusPerDamage = 1.5,
	bulletHitParticleBounceMultiplier = 0.1,
	titleOptionCount = 4,
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
	frontThrusterAnimationFrequency = 20,
	explosionImplosionColourNoiseRange = 0.2,
	explosionImplosionColourAdd = 0.2,
	healthBarLength = 60,
	healthBarWidth = 4,
	healthBarPadding = 2,
	textCanvasPad = 24,
	textCanvasY = gameHeight / 2,
	textFadeDistance = 8,
	titleScrollSpeed = 100,
	playerSpawnTime = 0.75,
	firstNormalPowerupWave = 6,
	firstSuperPowerupWave = 14,
	revealedPowerupRadius = 4,
	playBackgroundRushSpeed = 100,
	revealedPowerupSourceGravity = 75,
	newLifePerScore = 2000,
	pauseQuitTimerLength = 2
}

local controls = {
	up = "w",
	down = "s",
	left = "a",
	right = "d",
	shoot = "space",
	pause = "escape",
	slow = "lshift"
}

local gameState, paused, pauseFlashTimer

-- Variables for all states
local backgroundParticleBlockLayers

local titleVars, playVars, scoreScreenVars

local gameCanvas, canvasScale, font, titleFadeShader

local function noiseColour(colour, range)
	return {
		math.min(1, math.max(0, colour[1] + (love.math.random() - 0.5) * range)),
		math.min(1, math.max(0, colour[2] + (love.math.random() - 0.5) * range)),
		math.min(1, math.max(0, colour[3] + (love.math.random() - 0.5) * range))
	}
end

local function addToColour(colour, amount)
	return {
		math.min(1, math.max(0, colour[1] + amount)),
		math.min(1, math.max(0, colour[2] + amount)),
		math.min(1, math.max(0, colour[3] + amount))
	}
end

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
			colour = addToColour(noiseColour(shallowClone(colour), consts.explosionImplosionColourNoiseRange), consts.explosionImplosionColourAdd)
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
			colour = addToColour(noiseColour(shallowClone(colour), consts.explosionImplosionColourNoiseRange), consts.explosionImplosionColourAdd),
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
	local maxHealth = 4
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
		maxHealth = maxHealth,
		health = maxHealth,
		dead = false,
		colour = {0.6, 0.2, 0.2},
		contactInvulnerabilityTimerLength = 1,
		contactInvulnerabilityTimer = nil,
		flashAnimationSpeed = 30,
		spawning = true,
		spawnTimer = not assets.audio.gameStart:isPlaying() and consts.playerSpawnTime or nil,
		powerups = {},
		killStreak = 0
	}
	if not assets.audio.gameStart:isPlaying() then
		implode(playVars.player.radius, playVars.player.pos, playVars.player.colour, consts.playerSpawnTime)
	end
end

local function getCurBacktrackLimit()
	local screenTopInWorldSpace = playVars.player.pos.y - gameHeight / 2 - playVars.cameraYOffset
	return screenTopInWorldSpace + gameHeight / 2 + consts.cameraYOffsetMax
end

local function randomiseTimerLength(length)
	return length * (love.math.random() * 0.5 + 3/4)
end

local function spawnPowerup(super)
	local powerupSource = {
		-- pos and vel unset
		radius = 7,
		super = super,
		colour = super and {0.36, 0.45, 0.5} or {0.4, 0.4, 0.5},
		revealed = false,
		powerup = super and "hyperBeam" or "doubleBullets", -- Should be easy enough to add more powerups
		scoreToGive = super and 75 or 50
	}
	local speed = (super and 55 or 50) * math.lerp(1, 1.5, (playVars.waveNumber - 1) / (consts.finalNonBossWave + 1 - 1))
	local yMin, yMax = gameHeight / 4, gameHeight / 2
	local y = love.math.random() * (yMax - yMin) + yMin
	local x = powerupSource.radius * 0.1
	if love.math.random() < 0.5 then
		x = gameWidth - x
	end
	local pos = vec2(x, y)
	local pos2 = vec2(gameWidth - x, gameHeight / 2 - y)
	powerupSource.vel = normaliseOrZero(pos2 - pos) * speed
	local screenTopInWorldSpace = playVars.player.pos.y - gameHeight / 2 - playVars.cameraYOffset
	pos.y = pos.y + screenTopInWorldSpace
	powerupSource.pos = pos
	playVars.powerupSources:add(powerupSource)
end

local function nextWave()
	gameState = "play"
	playVars.waveNumber = playVars.waveNumber and (playVars.waveNumber + 1) or playVars.startWave
	if playVars.waveNumber == playVars.startWave then
		love.audio.play(assets.audio.gameStart)
	end
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
	playVars.powerupSources = list()

	generatePlayer(true)
	playVars.backtrackLimit = getCurBacktrackLimit()

	playVars.enemyPool = {}
	for k, v in pairs(registry.enemies) do
		playVars.enemyPool[k] = math.floor(v.count(playVars.waveNumber))
	end
	local lerpFactor = (playVars.waveNumber - 1) / (consts.finalNonBossWave + 1 - 1)
	playVars.spawnAttemptTimerLength = math.lerp(1, 0.25, lerpFactor)
	playVars.spawnAttemptTimer = playVars.spawnAttemptTimerLength -- Doesn't get used while spawning and gets reset when the player actually spawns
	playVars.maxEnemies = math.floor(math.lerp(4, 10, lerpFactor))
	playVars.minEnemiesToSpawn = math.floor(math.lerp(2, 3, lerpFactor))
	playVars.maxEnemiesToSpawn = math.floor(math.lerp(3, 6, lerpFactor))

	if playVars.waveNumber >= consts.firstNormalPowerupWave then
		playVars.normalPowerupsLeft = math.floor(math.lerp(1, 5, lerpFactor))
		playVars.normalPowerupSourceSpawnTimerLength = math.floor(math.lerp(30, 5, lerpFactor))
		playVars.normalPowerupSourceSpawnTimer = randomiseTimerLength(playVars.normalPowerupSourceSpawnTimerLength)
	else
		playVars.normalPowerupsLeft = 0
		playVars.normalPowerupSourceSpawnTimerLength = nil
		playVars.normalPowerupSourceSpawnTimer = nil
	end

	if playVars.waveNumber >= consts.firstSuperPowerupWave then
		playVars.superPowerupsLeft = math.floor(math.lerp(1, 2, lerpFactor))
		playVars.superPowerupSourceSpawnTimerLength = math.floor(math.lerp(30, 7.5, lerpFactor))
		playVars.superPowerupSourceSpawnTimer = randomiseTimerLength(playVars.normalPowerupSourceSpawnTimerLength)
	else
		playVars.superPowerupsLeft = 0
		playVars.superPowerupSourceSpawnTimer = nil
		playVars.superPowerupSourceSpawnTimer = nil
	end
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
		-- {distance = 6, blocks = {}},
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
	titleVars.textCanvas = love.graphics.newCanvas(gameWidth - consts.textCanvasPad * 2, gameHeight - consts.textCanvasY - borderSize)
	titleVars.textScroll = 0

	titleVars.storyText = love.filesystem.read("story.txt")
	local _, lines = font:getWrap(titleVars.storyText, titleVars.textCanvas:getWidth())
	titleVars.storyTextLines = lines
	titleVars.storyTextScrollMax = math.max(0, #lines * font:getHeight() - titleVars.textCanvas:getHeight())

	titleVars.creditsText = love.filesystem.read("credits.txt")
	local _, lines = font:getWrap(titleVars.creditsText, titleVars.textCanvas:getWidth())
	titleVars.creditsTextLines = lines
	titleVars.creditsTextScrollMax = math.max(0, #lines * font:getHeight() - titleVars.textCanvas:getHeight())

	titleFadeShader = love.graphics.newShader("titleFadeShader.glsl")
	titleFadeShader:send("canvasSize", {titleVars.textCanvas:getDimensions()})
	titleFadeShader:send("fadeDistance", consts.textFadeDistance)
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
	playVars.noBacktracking = true
	playVars.startWave = 1
	playVars.timeSpentInPlay = 0

	nextWave()
end

local function recordScore(name)
	assert(not playVars.scoreRecorded, "Attempted to record score despite it already having been recorded")
	local scoreToRecord =
		playVars.onResultsScreen and playVars.totalScore or
		playVars.gameOver and playVars.gameOverTotalScore or
		(playVars.totalScore + playVars.waveScore)
	local scoreString = table.concat({
		version,
		os.time(),
		playVars.startWave,
		playVars.waveNumber,
		playVars.gameOver and "gameOver" or checkAllEnemiesDefeatedAndEnemyBulletsGone() and "quitWhileAllOppositionDefeated" or "quitDuringPlay",
		scoreToRecord,
		math.floor(playVars.timeSpentInPlay),
		name
	}, " ") .. "\n"
	local success, errorMessage = love.filesystem.append("scores.txt", scoreString)
	if not success then
		-- TODO
	end
	playVars.scoreRecorded = true
end

local function decodeScoreRecord(line)
	local words = {}
	for word in line:gmatch("%S+") do
		words[#words+1] = word
	end
	local record = {
		version = words[1],
		timestamp = tonumber(words[2]),
		startWave = tonumber(words[3]),
		endWave = tonumber(words[4]),
		result = words[5],
		score = tonumber(words[6]),
		timeSpentInPlay = tonumber(words[7])
	}
	record.name = line:gsub(string.rep("%S+%s", 7), "") -- Handle (double or more) spaces in name
	record.symbol =
		(record.result == "quitWhileAllOppositionDefeated" and record.endWave == consts.finalNonBossWave + 1) and "star" or
		record.result == "quitWhileAllOppositionDefeated" and "tick" or
		record.result == "quitDuringPlay" and "door" or
		record.result == "gameOver" and "skull"
	record.line = line
	return record
end

local function initScoreScreenState()
	gameState = "scoreScreen"

	scoreScreenVars = {}

	if not love.filesystem.getInfo("scores.txt") then
		scoreScreenVars.noScores = true
		scoreScreenVars.scoresRecorded = 0
		return
	end

	scoreScreenVars.scores = {}
	scoreScreenVars.startingWaveScoreSets = {}
	scoreScreenVars.startingWaveScoreSetsFilteredByVersion = {}
	scoreScreenVars.startingWaveScoreSetsVictoriesOnly = {}
	scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly = {}
	local i = 1
	for line in love.filesystem.lines("scores.txt") do
		local record = decodeScoreRecord(line)
		record.index = i
		scoreScreenVars.scores[#scoreScreenVars.scores+1] = record

		scoreScreenVars.startingWaveScoreSets[record.startWave] = scoreScreenVars.startingWaveScoreSets[record.startWave] or {startWave = record.startWave}
		scoreScreenVars.startingWaveScoreSets[record.startWave][#scoreScreenVars.startingWaveScoreSets[record.startWave]+1] = record

		if record.version == version then
			scoreScreenVars.startingWaveScoreSetsFilteredByVersion[record.startWave] = scoreScreenVars.startingWaveScoreSetsFilteredByVersion[record.startWave] or {startWave = record.startWave}
			scoreScreenVars.startingWaveScoreSetsFilteredByVersion[record.startWave][#scoreScreenVars.startingWaveScoreSetsFilteredByVersion[record.startWave]+1] = record
		end

		if record.symbol == "star" then
			scoreScreenVars.startingWaveScoreSetsVictoriesOnly[record.startWave] = scoreScreenVars.startingWaveScoreSetsVictoriesOnly[record.startWave] or {startWave = record.startWave}
			scoreScreenVars.startingWaveScoreSetsVictoriesOnly[record.startWave][#scoreScreenVars.startingWaveScoreSetsVictoriesOnly[record.startWave]+1] = record
		end

		if record.version == version and record.symbol == "star" then
			scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly[record.startWave] = scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly[record.startWave] or {startWave = record.startWave}
			scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly[record.startWave][#scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly[record.startWave]+1] = record
		end

		i = i + 1
	end
	scoreScreenVars.scoresRecorded = #scoreScreenVars.scores

	local function closeGaps(t)
		local highest = 0
		for k, v in pairs(t) do
			if type(k) == "number" then
				highest = math.max(highest, k)
			end
		end

		local count = 0
		for i = 1, highest do
			if t[i] then
				count = count + 1
				t[count] = t[i]
			end
		end
		for i = count + 1, highest do
			t[i] = nil
		end

		return t
	end

	closeGaps(scoreScreenVars.startingWaveScoreSetsFilteredByVersion)
	closeGaps(scoreScreenVars.startingWaveScoreSets)
	closeGaps(scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly)
	closeGaps(scoreScreenVars.startingWaveScoreSetsVictoriesOnly)

	local function cloneScoreSets(sets)
		local ret = {}
		for i, v in ipairs(sets) do
			ret[i] = {}
			for k, v2 in pairs(v) do
				ret[i][k] = v2
			end
		end
		return ret
	end

	local function sortScoreSetsByTimestamp(sets)
		for i, set in ipairs(sets) do
			table.sort(set, function(a, b)
				if a.timestamp == b.timestamp then -- The idea is that timestamp order and index order might not be the same if you concatenated two score.txt files
					return a.index < b.index
				end
				return a.timestamp < b.timestamp
			end)
		end
		return sets
	end
	local function sortScoreSetsByScore(sets)
		for i, set in ipairs(sets) do
			table.sort(set, function(a, b)
				if a.score == b.score then
					return a.index < b.index
				end
				return a.score < b.score
			end)
		end
		return sets
	end
	local function sortScoreSetsByTimeSpentInPlay(sets)
		for i, set in ipairs(sets) do
			table.sort(set, function(a, b)
				if a.score == b.score then
					return a.index < b.index
				end
				return a.timeSpentInPlay > b.timeSpentInPlay
			end)
		end
		return sets
	end

	scoreScreenVars.displayedSets = {
		victoriesOnly = {
			filterVersionSortScore = sortScoreSetsByScore(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly)),
			sortScore = sortScoreSetsByScore(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsVictoriesOnly)),
			filterVersionSortTimestamp = sortScoreSetsByTimestamp(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly)),
			sortTimestamp = sortScoreSetsByTimestamp(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsVictoriesOnly)),
			filterVersionSortTimeSpent = sortScoreSetsByTimeSpentInPlay(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsFilteredByVersionVictoriesOnly)),
			sortTimeSpent = sortScoreSetsByTimeSpentInPlay(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsVictoriesOnly))
		},
		all = {
			filterVersionSortScore = sortScoreSetsByScore(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsFilteredByVersion)),
			sortScore = sortScoreSetsByScore(cloneScoreSets(scoreScreenVars.startingWaveScoreSets)),
			filterVersionSortTimestamp = sortScoreSetsByTimestamp(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsFilteredByVersion)),
			sortTimestamp = sortScoreSetsByTimestamp(cloneScoreSets(scoreScreenVars.startingWaveScoreSets)),
			filterVersionSortTimeSpent = sortScoreSetsByTimeSpentInPlay(cloneScoreSets(scoreScreenVars.startingWaveScoreSetsFilteredByVersion)),
			sortTimeSpent = sortScoreSetsByTimeSpentInPlay(cloneScoreSets(scoreScreenVars.startingWaveScoreSets))
		}
	}
	scoreScreenVars.scoreSetIndex = 1
	scoreScreenVars.filteringByVersion = true
	scoreScreenVars.sortingBy = "score"
	scoreScreenVars.configCursor = 0
end

local function victory()
	-- play victory sfx, centre on screen and fly away, scroll victory text, add to score like on results screen...
	playVars.victory = true
	recordScore("Names are NYI")
end

local function getScoreScreenSetsToShow()
	local choices = scoreScreenVars.displayedSets[scoreScreenVars.victoriesOnly and "victoriesOnly" or "all"]
	if scoreScreenVars.sortingBy == "score" then
		if scoreScreenVars.filteringByVersion then
			return choices.filterVersionSortScore
		else
			return choices.sortScore
		end
	elseif scoreScreenVars.sortingBy == "timestamp" then
		if scoreScreenVars.filteringByVersion then
			return choices.filterVersionSortTimestamp
		else
			return choices.sortTimestamp
		end
	elseif scoreScreenVars.sortingBy == "timeSpent" then
		if scoreScreenVars.filteringByVersion then
			return choices.filterVersionSortTimeSpent
		else
			return choices.sortTimeSpent
		end
	end
end

local function tryRecordQuitScore()
	if consts.playLikeStates[gameState] and not playVars.gameOver and not playVars.victory then
		recordScore("Names are NYI") -- TEMP
	end
end

function love.quit()
	tryRecordQuitScore()

	-- if alreadyAskingForName then
	-- 	return false
	-- else
	-- 	return true
	-- end
end

function love.load()
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

	initTitleState()
end

local function getPlayerBulletsCostUsed()
	local use = 0
	for i = 1, playVars.playerBullets.size do
		use = use + playVars.playerBullets:get(i).cost
	end
	return use
end

local function shootBullet()
	if checkAllEnemiesDefeatedAndEnemyBulletsGone() and playVars.powerupSources.size == 0 then
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
			playVars.pauseQuitTimer = consts.pauseQuitTimerLength
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
			if titleVars.textView then
				if key == controls.shoot then
					titleVars.textView = false
				end
			else
				if key == controls.up then
					titleVars.cursorPos = (titleVars.cursorPos - 1) % consts.titleOptionCount
				elseif key == controls.down then
					titleVars.cursorPos = (titleVars.cursorPos + 1) % consts.titleOptionCount
				elseif key == controls.shoot then
					if titleVars.cursorPos == 0 then
						initPlayState()
					elseif titleVars.cursorPos == 1 then
						initScoreScreenState()
					elseif titleVars.cursorPos == 2 then
						titleVars.textView = true
						titleVars.textScroll = 0
						titleVars.textMode = "story"
					elseif titleVars.cursorPos == 3 then
						titleVars.textView = true
						titleVars.textScroll = 0
						titleVars.textMode = "credits"
					end
				end
			end
		elseif gameState == "waveWon" and playVars.onResultsScreen then
			if key == controls.shoot then
				nextWave()
			end
		elseif gameState == "scoreScreen" then
			local sortTypes = {
				"score", score = 1,
				"timeSpent", timeSpent = 2,
				"timestamp", timestamp = 3
			}
			if key == controls.shoot then
				gameState = "title"
			elseif key == controls.left then
				if scoreScreenVars.configCursor == 0 then
					scoreScreenVars.scoreSetIndex = (scoreScreenVars.scoreSetIndex - 1 - 1) % #getScoreScreenSetsToShow() + 1
				elseif scoreScreenVars.configCursor == 1 then
					scoreScreenVars.sortingBy = sortTypes[(sortTypes[scoreScreenVars.sortingBy] - 1 - 1) % #sortTypes + 1]
				elseif scoreScreenVars.configCursor == 2 then
					scoreScreenVars.filteringByVersion = not scoreScreenVars.filteringByVersion
					scoreScreenVars.scoreSetIndex = 1
				elseif scoreScreenVars.configCursor == 3 then
					scoreScreenVars.victoriesOnly = not scoreScreenVars.victoriesOnly
					scoreScreenVars.scoreSetIndex = 1
				end
			elseif key == controls.right then
				if scoreScreenVars.configCursor == 0 then
					scoreScreenVars.scoreSetIndex = (scoreScreenVars.scoreSetIndex + 1 - 1) % #getScoreScreenSetsToShow() + 1
				elseif scoreScreenVars.configCursor == 1 then
					scoreScreenVars.sortingBy = sortTypes[(sortTypes[scoreScreenVars.sortingBy] + 1 - 1) % #sortTypes + 1]
				elseif scoreScreenVars.configCursor == 2 then
					scoreScreenVars.filteringByVersion = not scoreScreenVars.filteringByVersion
					scoreScreenVars.scoreSetIndex = 1
				elseif scoreScreenVars.configCursor == 3 then
					scoreScreenVars.victoriesOnly = not scoreScreenVars.victoriesOnly
					scoreScreenVars.scoreSetIndex = 1
				end
			elseif key == controls.up then
				scoreScreenVars.configCursor = (scoreScreenVars.configCursor - 1) % 4
			elseif key == controls.down then
				scoreScreenVars.configCursor = (scoreScreenVars.configCursor + 1) % 4
			end
		end
	end
end

local function getBlockCameraPos()
	return
		(gameState == "title" or gameState == "scoreScreen") and
		titleVars.titleCameraPos or
		consts.playLikeStates[gameState] and
		(playVars.player.pos * vec2(0 and 1, 1) - vec2(0, playVars.time * consts.playBackgroundRushSpeed))
end

function love.update(dt)
	if gameState ~= "play" then
		paused = false
	end
	if paused then
		pauseFlashTimer = (pauseFlashTimer + dt) % consts.pauseFlashTimerLength
		if love.keyboard.isDown("space") then
			playVars.pauseQuitTimer = playVars.pauseQuitTimer - dt
			if playVars.pauseQuitTimer <= 0 then
				tryRecordQuitScore()
				initTitleState()
				playVars = nil
			end
		else
			playVars.pauseQuitTimer = consts.pauseQuitTimerLength
		end
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
		local cameraPos = getBlockCameraPos()
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
	if gameState == "title" or gameState == "scoreScreen" then
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

		if titleVars.textView then
			if love.keyboard.isDown(controls.up) then
				titleVars.textScroll = titleVars.textScroll - consts.titleScrollSpeed * dt
			end
			if love.keyboard.isDown(controls.down) then
				titleVars.textScroll = titleVars.textScroll + consts.titleScrollSpeed * dt
			end
			local maxScroll = titleVars.textMode == "story" and titleVars.storyTextScrollMax or titleVars.textMode == "credits" and titleVars.creditsTextScrollMax
			titleVars.textScroll = math.max(0, math.min(maxScroll, titleVars.textScroll))
		end
	elseif consts.playLikeStates[gameState] then
		playVars.time = playVars.time + dt

		if isPlayerPresent() and not checkAllEnemiesDefeatedAndEnemyBulletsGone() and gameState == "play" then
			if playVars.normalPowerupSourceSpawnTimer then
				playVars.normalPowerupSourceSpawnTimer = playVars.normalPowerupSourceSpawnTimer - dt
				if playVars.normalPowerupSourceSpawnTimer <= 0 then
					if playVars.normalPowerupsLeft <= 0 then
						playVars.normalPowerupSourceSpawnTimer = nil
					else
						spawnPowerup(false)
						playVars.normalPowerupsLeft = playVars.normalPowerupsLeft - 1
						if playVars.normalPowerupsLeft <= 0 then
							playVars.normalPowerupSourceSpawnTimer = nil
						else
							playVars.normalPowerupSourceSpawnTimer = randomiseTimerLength(playVars.normalPowerupSourceSpawnTimerLength)
						end
					end
				end
			end
			if playVars.superPowerupSourceSpawnTimer then
				playVars.superPowerupSourceSpawnTimer = playVars.superPowerupSourceSpawnTimer - dt
				if playVars.superPowerupSourceSpawnTimer <= 0 then
					if playVars.superPowerupsLeft <= 0 then
						playVars.superPowerupSourceSpawnTimer = nil
					else
						spawnPowerup(true)
						playVars.superPowerupsLeft = playVars.superPowerupsLeft - 1
						if playVars.superPowerupsLeft <= 0 then
							playVars.superPowerupSourceSpawnTimer = nil
						else
							playVars.superPowerupSourceSpawnTimer = randomiseTimerLength(playVars.superPowerupSourceSpawnTimerLength)
						end
					end
				end
			end
		end

		playVars.player.fireBackThrusters = false
		playVars.player.fireFrontThrusters = false

		if playVars.player.spawning and not assets.audio.gameStart:isPlaying() then
			if not playVars.player.spawnTimer then
				playVars.player.spawnTimer = consts.playerSpawnTime
				implode(playVars.player.radius, playVars.player.pos, playVars.player.colour, consts.playerSpawnTime)
			end
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
				playVars.gameOverTotalScore = playVars.totalScore + playVars.waveScore
			else
				playVars.preRespawnCentringTimer = consts.preRespawnCentringTimerLength
			end
			playVars.spareLives = math.max(0, playVars.spareLives - 1)
			local enemyBulletsToDelete = {}
			for i = 1, playVars.enemyBullets.size do
				local enemyBullet = playVars.enemyBullets:get(i)
				if enemyBullet.disappearOnPlayerDeathAndAllEnemiesDefeated then
					explode(enemyBullet.radius, enemyBullet.pos, enemyBullet.colour)
					enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
				end
			end
			for _, enemyBullet in ipairs(enemyBulletsToDelete) do
				playVars.enemyBullets:remove(enemyBullet)
			end
		end
		if isPlayerPresent() then
			if not (checkAllEnemiesDefeatedAndEnemyBulletsGone() and playVars.powerupSources.size == 0) and gameState == "play" then
				playVars.timeSpentInPlay = playVars.timeSpentInPlay + dt
			end

			local slow = love.keyboard.isDown(controls.slow)
			local maxSpeedX = slow and 50 or playVars.player.maxSpeedX
			local maxSpeedUp = slow and 50 or playVars.player.maxSpeedUp
			local maxSpeedDown = slow and 50 or playVars.player.maxSpeedDown
			local notFlyingAway = not (checkAllEnemiesDefeatedAndEnemyBulletsGone() and playVars.powerupSources.size == 0) and gameState == "play"

			local function handleAxis(current, target, acceleration, dt)
				if acceleration > 0 then
					return math.min(target, current + acceleration * dt)
				elseif acceleration < 0 then
					return math.max(target, current + acceleration * dt)
				end
			
				return current
			end
			-- player movement x
			local targetVelX = 0
			if notFlyingAway and love.keyboard.isDown(controls.left) then
				targetVelX = targetVelX - (slow and 50 or playVars.player.maxSpeedX)
			end
			if notFlyingAway and love.keyboard.isDown(controls.right) then
				targetVelX = targetVelX + (slow and 50 or playVars.player.maxSpeedX)
			end
			local difference = targetVelX - playVars.player.vel.x
			local accel = math.sign(difference) * playVars.player.accelX
			playVars.player.vel.x = handleAxis(playVars.player.vel.x, targetVelX, accel, dt)
			-- player movement y
			local targetVelY = 0
			if notFlyingAway and love.keyboard.isDown(controls.up) then
				targetVelY = targetVelY - (slow and 50 or playVars.player.maxSpeedUp)
				playVars.player.fireBackThrusters = not slow
			end
			if notFlyingAway and love.keyboard.isDown(controls.down) then
				targetVelY = targetVelY + (slow and 50 or playVars.player.maxSpeedDown)
				playVars.player.fireFrontThrusters = not slow
			end
			if not notFlyingAway then
				targetVelY = -playVars.player.maxSpeedUp
				playVars.player.fireBackThrusters = true
				playVars.player.fireFrontThrusters = false
			end
			local difference = targetVelY - playVars.player.vel.y
			local accel = difference > 0 and playVars.player.accelDown or difference < 0 and -playVars.player.accelUp or 0
			playVars.player.vel.y = handleAxis(playVars.player.vel.y, targetVelY, accel, dt)
			
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

			local prevPlayerPosY = playVars.player.pos.y
			playVars.player.pos = playVars.player.pos + playVars.player.vel * dt
			if playVars.noBacktracking and playVars.player.pos.y > playVars.backtrackLimit then
				playVars.player.vel.y = 0
				playVars.player.pos.y = playVars.backtrackLimit
			end
			local yChange = playVars.player.pos.y - prevPlayerPosY
			local cameraSlowdownFactorSameDirection = playVars.noBacktracking and 1 or (consts.cameraYOffsetMax - playVars.cameraYOffset) / consts.cameraYOffsetMax
			local cameraSlowdownFactorOppositeDirections = (1 - (consts.cameraYOffsetMax - playVars.cameraYOffset) / consts.cameraYOffsetMax)
			local cameraSlowdownFactor = math.sign(playVars.player.vel.y) * math.sign(playVars.cameraYOffset) == -1 and cameraSlowdownFactorOppositeDirections or cameraSlowdownFactorSameDirection
			if notFlyingAway then
				playVars.cameraYOffset = math.min(consts.cameraYOffsetMax, math.max(-consts.cameraYOffsetMax * 0, playVars.cameraYOffset + yChange * cameraSlowdownFactor))
			else
				playVars.cameraYOffset = playVars.cameraYOffset + yChange
			end

			if playVars.player.pos.x < consts.borderSize then
				playVars.player.pos.x = consts.borderSize
				playVars.player.vel.x = math.max(0, playVars.player.vel.x)
			elseif playVars.player.pos.x > gameWidth - consts.borderSize then
				playVars.player.pos.x = gameWidth - consts.borderSize
				playVars.player.vel.x = math.min(0, playVars.player.vel.x)
			end

			playVars.backtrackLimit = math.min(playVars.backtrackLimit, getCurBacktrackLimit()) 
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

		if playVars.gameOver then
			if playVars.playerBullets.size == 0 then -- Let the score loss of bullets missing and player dying all accumulate before calculating gameOverTotalScore
				if not playVars.gameOverTextPresent then
					if playVars.gameOverTextWaitTimer then
						if playVars.playerBullets.size == 0 then
							playVars.gameOverTextWaitTimer = playVars.gameOverTextWaitTimer - dt
							if playVars.gameOverTextWaitTimer <= 0 then
								playVars.gameOverTextPresent = true
								recordScore("Names are NYI")
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
				local hit = false
				for j = 1, playVars.enemies.size do
					local enemy = playVars.enemies:get(j)
					if vec2.distance(enemy.pos, playerBullet.pos) <= enemy.radius then
						hit = true
						deleteThesePlayerBullets[#deleteThesePlayerBullets + 1] = playerBullet
						enemy.health = enemy.health - playerBullet.damage
						if enemy.health > 0 then
							explode(playerBullet.damage * consts.explosionSourceRadiusPerDamage, playerBullet.pos, shallowClone(enemy.colour), -playerBullet.vel * consts.bulletHitParticleBounceMultiplier)
						end
					end
				end
				if not hit then
					for j = 1, playVars.powerupSources.size do
						local source = playVars.powerupSources:get(j)
						if vec2.distance(source.pos, playerBullet.pos) <= source.radius then
							if not source.revealed then
								source.revealed = true
								local towardsCentreDir = math.sign(gameWidth / 2 - source.pos.x)
								source.vel = vec2(love.math.random() * 50 * towardsCentreDir, -50)
								source.radius = consts.revealedPowerupRadius
								explode(20, source.pos, shallowClone(source.colour))
								hit = true
								deleteThesePlayerBullets[#deleteThesePlayerBullets+1] = playerBullet
							end
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
						value = tostring(scoreAdd),
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
					if #posDiff > 0 and not (enemy.aiType == "mineLayer" and playVars.player.pos.y < enemy.pos.y) then
						for i = 0, enemy.bulletCount - 1 do
							local angleOffset = enemy.bulletCount == 1 and 0 or (i / (enemy.bulletCount - 1) - 0.5) * enemy.bulletSpreadAngle
							playVars.enemyBullets:add({
								pos = enemy.pos,
								vel = enemy.bulletSpeed * vec2.rotate(vec2.normalise(posDiff), angleOffset),
								radius = enemy.bulletRadius,
								damage = enemy.bulletDamage,
								disappearOnPlayerDeathAndAllEnemiesDefeated = enemy.bulletsDisappearOnPlayerDeathAndAllEnemiesDefeated,
								colour = shallowClone(enemy.bulletColour or {1, 1, 1})
							})
						end
					end
				end
			end
		end
		for _, enemy in ipairs(enemiesToDelete) do
			playVars.enemies:remove(enemy)
		end

		local enemyPoolIsEmpty = true
		for k, v in pairs(playVars.enemyPool) do
			if v > 0 then
				enemyPoolIsEmpty = false
				break
			end
		end
		local enemyBulletsToDelete = {}
		for i = 1, playVars.enemyBullets.size do
			local enemyBullet = playVars.enemyBullets:get(i)
			enemyBullet.pos = enemyBullet.pos + enemyBullet.vel * dt
			if circleOffScreen(enemyBullet.radius, enemyBullet.pos) then
				enemyBulletsToDelete[#enemyBulletsToDelete+1] = enemyBullet
			elseif playVars.enemies.size == 0 and enemyPoolIsEmpty and playVars.enemiesToMaterialise.size == 0 and enemyBullet.disappearOnPlayerDeathAndAllEnemiesDefeated then
				explode(enemyBullet.radius, enemyBullet.pos, shallowClone(enemyBullet.colour))
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
				if enemy.aiType == "minelayer" then
					enemy.targetVel = vec2(0, -enemy.speed)
				else
					enemy.targetVel = enemy.speed * vec2.normalise(playVars.player.pos - enemy.pos)
					enemy.targetVel.y = math.abs(enemy.targetVel.y)
				end
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
				local y
				if registryEntry.spawnAtTop then
					y = love.math.random() * gameHeight / 16 + screenTopInWorldSpace
				else
					y = love.math.random() * gameHeight / 4 + screenTopInWorldSpace
				end
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
					aiType = registryEntry.aiType,
					bulletsDisappearOnPlayerDeathAndAllEnemiesDefeated = registryEntry.bulletsDisappearOnPlayerDeathAndAllEnemiesDefeated,
					bulletColour = registryEntry.bulletColour,
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

		local powerupSourcesToDelete = {}
		for i = 1, playVars.powerupSources.size do
			local source = playVars.powerupSources:get(i)
			source.pos = source.pos + source.vel * dt
			if source.revealed then
				source.vel.y = source.vel.y + consts.revealedPowerupSourceGravity * dt
			end
			if source.revealed and isPlayerPresent() and vec2.distance(source.pos, playVars.player.pos) <= source.radius + playVars.player.radius then
				playVars.waveScore = playVars.waveScore + source.scoreToGive
				playVars.floatingTexts:add({
					value = tostring(source.scoreToGive),
					pos = vec2.clone(source.pos),
					vel = vec2(0, -20),
					timer = consts.scoreTextTimerLength
				})
				powerupSourcesToDelete[#powerupSourcesToDelete+1] = source
				givePowerup(source.powerup)
			elseif circleOffScreen(source.radius, source.pos) then
				powerupSourcesToDelete[#powerupSourcesToDelete+1] = source
			end
		end
		for _, source in ipairs(powerupSourcesToDelete) do
			playVars.powerupSources:remove(source)
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
			playVars.powerupSources.size == 0 and
			playVars.playerBullets.size == 0 and
			isPlayerPresent()
		then
			winWave()
		end

		if gameState == "play" and isPlayerPresent() and not checkAllEnemiesDefeatedAndEnemyBulletsGone() then -- not checking playVars.powerupSources.size == 0
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
					local addToTotal = playVars.waveScore + lifeBonus + timeBonus
					local livesToAward = 0
					while addToTotal > 0 do
						local nextMultipleOfNewLifePerScore = playVars.totalScore + (consts.newLifePerScore - playVars.totalScore % consts.newLifePerScore) -- excluding the one total is on if it is one
						local prevTotal = playVars.totalScore
						playVars.totalScore = math.min(nextMultipleOfNewLifePerScore, playVars.totalScore + addToTotal)
						if playVars.totalScore == nextMultipleOfNewLifePerScore then
							livesToAward = livesToAward + 1
				end
						addToTotal = addToTotal - (playVars.totalScore - prevTotal)
			end
					playVars.resultsScreenVars.addedLives = livesToAward
					playVars.spareLives = playVars.spareLives + livesToAward
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
		love.graphics.setColor(1, 1, 1)
		love.graphics.scale(canvasScale) -- The text does remain perfectly aligned
		local text = "Paused"
		love.graphics.print(text, gameWidth / 2 - font:getWidth(text) / 2, gameHeight /2 - font:getHeight())
		local text = "Hold shoot for 2 seconds to quit"
		love.graphics.print(text, gameWidth / 2 - font:getWidth(text) / 2, gameHeight / 2)
		love.graphics.setCanvas()
		return
	end

	love.graphics.setCanvas(gameCanvas)
	love.graphics.clear()

	if backgroundParticleBlockLayers and not (playVars and playVars.onResultsScreen) then
		local cameraPos = getBlockCameraPos()
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

		if titleVars.textView then
			love.graphics.origin()
			love.graphics.setCanvas(titleVars.textCanvas)
			love.graphics.clear()
			local lines = titleVars.textMode == "story" and titleVars.storyTextLines or titleVars.textMode == "credits" and titleVars.creditsTextLines
			for i, line in ipairs(lines) do
				love.graphics.printf(
					line,
					0,
					consts.textFadeDistance + font:getHeight() * (i - 1) - titleVars.textScroll,
					titleVars.textCanvas:getWidth(),
					font:getWidth(line) > 200 and "justify" or "left"
				)
			end
			love.graphics.setCanvas(gameCanvas)
			love.graphics.setShader(titleFadeShader)
			love.graphics.draw(titleVars.textCanvas, consts.textCanvasPad, consts.textCanvasY)
			love.graphics.setShader()
		else
			local texts = {
				"PLAY",
				"SCORES",
				"STORY",
				"CREDITS"
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
			love.graphics.origin()
			local text = "Move: WASD, shoot: Space, pause: Esc"
			love.graphics.print(text, gameWidth / 2 - font:getWidth(text) / 2, gameHeight - borderSize - font:getHeight() * 2)
			local text = "Extra life (at end of wave) every " .. consts.newLifePerScore .. " points"
			love.graphics.print(text, gameWidth / 2 - font:getWidth(text) / 2, gameHeight - borderSize - font:getHeight())
		end
	elseif gameState == "scoreScreen" then
		if scoreScreenVars.noScores then
			local text = "No scores to display"
			love.graphics.print(text, (gameWidth - font:getWidth(text)) / 2, (gameHeight - font:getHeight()) / 2)
		else
			local setsToShow = getScoreScreenSetsToShow()
			local setToShow = setsToShow[scoreScreenVars.scoreSetIndex]

			local linesPerEntry = 4
			local scoresToDisplay = 4
			if setToShow then
				local j = 0
				for i = #setToShow, #setToShow - (scoresToDisplay - 1), -1 do
					local record = setToShow[i]
					if not record then
						break
					end
					love.graphics.translate(borderSize, borderSize + j * font:getHeight() * (linesPerEntry + 0.5))
					local timeString = os.date("%Y-%m-%d %H:%M", record.timestamp)
					local versionString = record.version == "unknown" and "an unknown version" or ("version " .. record.version)
					local resultString =
						record.symbol == "star" and "was victorious" or
						record.symbol == "tick" and "quit while safe" or
						record.symbol == "door" and "quit during combat" or
						record.symbol == "skull" and "died"
					local timeSpentString = math.floor(record.timeSpentInPlay / 60) .. " mins and " .. (record.timeSpentInPlay % 60) .. " secs"
					local text =
						"\"" .. record.name .. "\" scored " .. record.score .. " points at\n" ..
						timeString .. " on waves " .. record.startWave .. "-" .. record.endWave .. " and\n" ..
						resultString .. " after " .. timeSpentString .. ",\n" ..
						"on " .. versionString .. ".\n"
					love.graphics.print(text, 0, 0)
					love.graphics.origin()
					j = j + 1
				end
			else
				local text = "No scores with this filter."
				love.graphics.print(text, borderSize, borderSize)
				love.graphics.origin()
			end
			love.graphics.translate(borderSize, borderSize + font:getHeight() * (linesPerEntry + 0.5) * scoresToDisplay)
			love.graphics.draw(assets.images.cursor, 0, font:getHeight() * scoreScreenVars.configCursor + font:getHeight() / 2 - assets.images.cursor:getHeight() / 2)
			love.graphics.translate(assets.images.cursor:getWidth(), 0)
			love.graphics.print(
				"Starting wave: " .. (setToShow and setToShow.startWave or "N/A") .. "\n" ..
				"Sorting by: " .. (scoreScreenVars.sortingBy == "timeSpent" and "time spent" or scoreScreenVars.sortingBy) .. (scoreScreenVars.sortingBy == "timeSpent" and not scoreScreenVars.victoriesOnly and " (showing non-victories)" or "") .. "\n" ..
				"Version filtering: " .. (scoreScreenVars.filteringByVersion and "yes" or "no") .. "\n" ..
				"Victories only: " .. (scoreScreenVars.victoriesOnly and "yes" or "no") .. "\n" ..
				"\n" ..
				scoreScreenVars.scoresRecorded .. " scores recorded",
			0, 0)
		end
	elseif consts.playLikeStates[gameState] then
		if gameState == "waveWon" and playVars.onResultsScreen then
			love.graphics.origin()
			local texts = {
				"PREV. TOTAL: " .. playVars.resultsScreenVars.prevTotalScore,
				"WAVE SCORE: " .. playVars.waveScore,
				"LIFE BONUS: " .. playVars.resultsScreenVars.lifeBonus,
				"TIME BONUS: " .. playVars.resultsScreenVars.timeBonus,
				"TOTAL SCORE: " .. playVars.totalScore,
				"LIVES AWARDED: " .. playVars.resultsScreenVars.addedLives,
				"TIME: " .. math.floor(math.floor(playVars.timeSpentInPlay) / 60) .. ":" .. string.format("%02d", (math.floor(playVars.timeSpentInPlay) % 60))
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
			for i = 1, playVars.powerupSources.size do
				local source = playVars.powerupSources:get(i)
				if source.revealed then
					if source.super then
						love.graphics.setColor(1, 0.25, 0.25)
					else
						love.graphics.setColor(0.25, 1, 0.25)
					end
					local glowRadius = 16
					love.graphics.draw(
						assets.images.glow,
						source.pos.x - glowRadius,
						source.pos.y - glowRadius,
						0,
						2 * glowRadius / assets.images.glow:getWidth(),
						2 * glowRadius / assets.images.glow:getHeight()
					)
					love.graphics.setColor(1, 1, 1)
					local asset = assets.images[source.powerup .. "PowerupSymbol"]
					love.graphics.draw(asset, source.pos.x - asset:getWidth() / 2, source.pos.y - asset:getHeight() / 2)
				elseif source.super then
					love.graphics.draw(assets.images.superPowerupContainer, source.pos.x - assets.images.superPowerupContainer:getWidth() / 2, source.pos.y - assets.images.superPowerupContainer:getHeight() / 2)
				else
					love.graphics.draw(assets.images.normalPowerupContainer, source.pos.x - assets.images.normalPowerupContainer:getWidth() / 2, source.pos.y - assets.images.normalPowerupContainer:getHeight() / 2)
				end
			end
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

			-- for i = 1, playVars.spareLives do
			-- 	love.graphics.draw(assets.images.player, gameWidth - i * assets.images.player:getWidth(), 0)
			-- end
			love.graphics.draw(assets.images.player, gameWidth - assets.images.player:getWidth(), font:getHeight() / 2 - assets.images.player:getHeight() / 2)
			local text = tostring(playVars.spareLives)
			love.graphics.print(text, gameWidth - assets.images.player:getWidth() - font:getWidth(text), 0)

			local hbx = gameWidth - 1 - consts.healthBarPadding * 2 - consts.healthBarWidth
			local hby = assets.images.player:getHeight() + 1
			love.graphics.setColor(0.5, 0.5, 0.5)
			love.graphics.rectangle("fill", hbx, hby, consts.healthBarPadding * 2 + consts.healthBarWidth, consts.healthBarPadding * 2 + consts.healthBarLength)
			love.graphics.setColor(1, 0.5, 0.5)
			love.graphics.rectangle("fill", hbx + consts.healthBarPadding, hby + consts.healthBarPadding, consts.healthBarWidth, consts.healthBarLength)
			love.graphics.setColor(0.5, 1, 0.5)
			local heightChange = math.round((1 - math.max(0, playVars.player.health) / playVars.player.maxHealth) * consts.healthBarLength)
			love.graphics.rectangle("fill", hbx + consts.healthBarPadding, hby + consts.healthBarPadding + heightChange, consts.healthBarWidth, consts.healthBarLength - heightChange)
			love.graphics.setColor(1, 1, 1)

			local text = playVars.waveNumber .. "/" .. (consts.finalNonBossWave + 1)
			love.graphics.print(text, gameWidth / 2 - font:getWidth(text) / 2, 0)
			local enemyCount = playVars.enemies.size + playVars.enemiesToMaterialise.size
			for _, count in pairs(playVars.enemyPool) do
				enemyCount = enemyCount + count
			end
			local text = tostring(enemyCount)
			love.graphics.print(text, gameWidth / 2 - font:getWidth(text) / 2, font:getHeight())

			if playVars.gameOverTextPresent then
				local gameOverText = "GAME OVER"
				local totalScoreText = "TOTAL SCORE: " .. playVars.gameOverTotalScore
				local timeText = "TIME: " .. math.floor(math.floor(playVars.timeSpentInPlay) / 60) .. ":" .. string.format("%02d", (math.floor(playVars.timeSpentInPlay) % 60))
				love.graphics.print(gameOverText, gameWidth / 2 - font:getWidth(gameOverText) / 2, gameHeight / 2 - 1.5 * font:getHeight())
				love.graphics.print(totalScoreText, gameWidth / 2 - font:getWidth(totalScoreText) / 2, gameHeight / 2 - 0.5 * font:getHeight())
				love.graphics.print(timeText, gameWidth / 2 - font:getWidth(timeText) / 2, gameHeight / 2 + 0.5 * font:getHeight())
			end

			love.graphics.print(playVars.totalScore, 1, 0)
			love.graphics.print(playVars.waveScore, 1, font:getHeight())
		end
	end

	love.graphics.origin()
	love.graphics.setCanvas()
	love.graphics.draw(gameCanvas, 0, 0, 0, canvasScale)
end
