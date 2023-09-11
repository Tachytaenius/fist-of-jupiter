local vec2 = require("lib.mathsies").vec2

local registry = {}

registry.enemies = {}
registry.enemyNameIdBiMap = {}
registry.numEnemies = 0
local nextId = 0
local function newEnemy(name, enemy)
	registry.enemies[name] = enemy
	registry.enemyNameIdBiMap[name] = nextId
	registry.enemyNameIdBiMap[nextId] = name
	nextId = nextId + 1
	registry.numEnemies = registry.numEnemies + 1
end
local firstGenPeakWave = 3
local secondGenPeakWave = 6
local thirdGenPeakWave = 12
local firstBossWave = 15
newEnemy("fighter1", {
	radius = 6,
	health = 1,
	colour = {0.5, 0.5, 0.6},
	speed = 75,
	shootTimerLength = 1,
	bulletSpeed = 200,
	bulletRadius = 1,
	bulletDamage = 1,
	bulletCount = 1,
	bulletSpreadAngle = 0,
	contactDamage = 2,
	accel = 150,
	defeatScore = 20,
	materialisationTime = 0.2,
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 5
		for i = 1, waveNumber do
			if i > 0 and i <= firstGenPeakWave then
				currentAmount = currentAmount + 2
			elseif i > firstGenPeakWave then
				currentAmount = currentAmount - 4
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("fighter2", {
	radius = 8,
	health = 2,
	colour = {0.5, 0.5, 0.6},
	speed = 100,
	shootTimerLength = 0.9,
	bulletSpeed = 210,
	bulletRadius = 1.5,
	bulletDamage = 0.5,
	bulletCount = 4,
	bulletSpreadAngle = math.tau / 180,
	contactDamage = 4,
	accel = 225,
	defeatScore = 30,
	materialisationTime = 0.35,
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			if i > firstGenPeakWave and i <= secondGenPeakWave then
				currentAmount = currentAmount + 3
			elseif i > secondGenPeakWave then
				currentAmount = currentAmount - 6
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("fighter3", {
	radius = 8,
	health = 3,
	colour = {0.5, 0.5, 0.6},
	speed = 125,
	shootTimerLength = 0.8,
	bulletSpeed = 220,
	bulletRadius = 2,
	bulletDamage = 1,
	bulletCount = 3,
	bulletSpreadAngle = math.tau / 150,
	contactDamage = 6,
	accel = 250,
	defeatScore = 35,
	materialisationTime = 0.5,
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			if i > secondGenPeakWave and i <= thirdGenPeakWave then
				currentAmount = currentAmount + 3
			elseif i > thirdGenPeakWave then
				currentAmount = currentAmount - 5
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("bomber1", {
	radius = 10,
	health = 2,
	colour = {0.6, 0.5, 0.6},
	speed = 50,
	shootTimerLength = 2,
	bulletSpeed = 150,
	bulletRadius = 2,
	bulletDamage = 2,
	bulletCount = 1,
	bulletSpreadAngle = 0,
	contactDamage = 3,
	accel = 125,
	defeatScore = 25,
	materialisationTime = 0.3,
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			i = i - 1
			if i > 0 and i <= firstGenPeakWave then
				currentAmount = currentAmount + 4
			elseif i > firstGenPeakWave then
				currentAmount = currentAmount - 5
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("bomber2", {
	radius = 12,
	health = 3,
	colour = {0.6, 0.5, 0.6},
	speed = 75,
	shootTimerLength = 1.5,
	bulletSpeed = 160,
	bulletRadius = 3,
	bulletDamage = 4,
	bulletCount = 1,
	bulletSpreadAngle = 0,
	contactDamage = 6,
	accel = 175,
	defeatScore = 35,
	materialisationTime = 0.5,
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			i = i - 1
			if i > firstGenPeakWave and i <= secondGenPeakWave then
				currentAmount = currentAmount + 2
			elseif i > secondGenPeakWave then
				currentAmount = currentAmount - 9
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("bomber3", {
	radius = 10,
	health = 4,
	colour = {0.6, 0.5, 0.6},
	speed = 100,
	shootTimerLength = 1.25,
	bulletSpeed = 170,
	bulletRadius = 4,
	bulletDamage = 6,
	bulletCount = 2,
	bulletSpreadAngle = math.tau/120,
	contactDamage = 10,
	accel = 200,
	defeatScore = 40,
	materialisationTime = 0.7,
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			i = i - 1
			if i > secondGenPeakWave and i <= thirdGenPeakWave then
				currentAmount = currentAmount + 2
			elseif i > thirdGenPeakWave then
				currentAmount = currentAmount - 12
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("minelayer1", {
	radius = 12,
	health = 3,
	colour = {0.1, 0.4, 0.2},
	speed = 200,
	shootTimerLength = 2,
	bulletSpeed = 25,
	bulletRadius = 5,
	bulletDamage = 4,
	bulletCount = 1,
	bulletSpreadAngle = 0,
	bulletsDisappearOnPlayerDeathAndAllEnemiesDefeated = true,
	contactDamage = 3,
	accel = 75,
	defeatScore = 25,
	materialisationTime = 0.5,
	spawnAtTop = true,
	aiType = "minelayer",
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			i = i - 2
			if i > 0 and i <= firstGenPeakWave then
				currentAmount = currentAmount + 4
			elseif i > firstGenPeakWave then
				currentAmount = currentAmount - 5
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("minelayer2", {
	radius = 13,
	health = 4,
	colour = {0.1, 0.4, 0.2},
	speed = 225,
	shootTimerLength = 1.5,
	bulletSpeed = 40,
	bulletRadius = 5,
	bulletDamage = 6,
	bulletCount = 3,
	bulletSpreadAngle = math.tau / 60,
	bulletsDisappearOnPlayerDeathAndAllEnemiesDefeated = true,
	contactDamage = 4,
	accel = 100,
	defeatScore = 40,
	materialisationTime = 0.4,
	spawnAtTop = true,
	aiType = "minelayer",
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			i = i - 2
			if i > firstGenPeakWave and i <= secondGenPeakWave then
				currentAmount = currentAmount + 2
			elseif i > secondGenPeakWave then
				currentAmount = currentAmount - 6
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("minelayer3", {
	radius = 11,
	health = 5,
	colour = {0.1, 0.4, 0.2},
	speed = 250,
	shootTimerLength = 1,
	bulletSpeed = 50,
	bulletRadius = 6,
	bulletDamage = 8,
	bulletCount = 5,
	bulletSpreadAngle = math.tau / 30,
	bulletsDisappearOnPlayerDeathAndAllEnemiesDefeated = true,
	contactDamage = 6,
	accel = 125,
	defeatScore = 50,
	materialisationTime = 0.3,
	spawnAtTop = true,
	aiType = "minelayer",
	count = function(waveNumber)
		if waveNumber >= firstBossWave then
			return 0
		end
		local currentAmount = 0
		for i = 1, waveNumber do
			i = i - 2
			if i > secondGenPeakWave and i <= thirdGenPeakWave then
				currentAmount = currentAmount + 1
			elseif i > thirdGenPeakWave then
				currentAmount = currentAmount - 3
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
})
newEnemy("commander1", {
	radius = 30,
	health = 0,
	subEnemies = {
		{
			radius = 10,
			health = 50,
			offset = vec2(-10, 0),
			shootTimerLength = 1,
			bulletSpeed = 150,
			bulletRadius = 2,
			bulletDamage = 2,
			bulletCount = 21, -- needs to be odd or else you can stand still and never get hit
			bulletSpreadAngle = math.tau / 2,
			colour = {0.8, 0.8, 0.6},
			type = "commander1Left"
		},
		{
			radius = 10,
			health = 50,
			offset = vec2(10, 0),
			shootTimerLength = 2,
			bulletSpeed = 175,
			bulletRadius = 3,
			bulletDamage = 4,
			bulletCount = 11, -- needs to be odd or else you can stand still and never get hit
			bulletSpreadAngle = math.tau / 2,
			colour = {0.8, 0.8, 0.6},
			type = "commander1Right"
		}
	},
	colour = {0.8, 0.8, 0.6},
	doesntShoot = true,
	speed = 200,
	deliberateSpeed = 100,
	contactDamage = 10,
	accel = 400,
	defeatScore = 100,
	materialisationTime = 1.5,
	boss = true,
	movementTimerLength = 2.5,
	slowdownRate = 50,
	implosionVelocityBoost = vec2(0, -750),
	aiType = "boss",
	shieldSwapTimerLength = 6,
	shieldRadius = 12,
	count = function(waveNumber)
		return waveNumber == firstBossWave and 1 or 0
	end
})

return registry
