local registry = {}

registry.enemies = {}
local firstGenPeakWave = 3
local secondGenPeakWave = 6
local thirdGenPeakWave = 12
registry.enemies.fighter1 = {
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
		local currentAmount = 5
		for i = 1, waveNumber do
			if i <= firstGenPeakWave then
				currentAmount = currentAmount + 2
			else
				currentAmount = currentAmount - 4
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
}
registry.enemies.fighter2 = {
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
}
registry.enemies.fighter3 = {
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
}
registry.enemies.bomber1 = {
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
		local currentAmount = 3
		for i = 1, waveNumber do
			if i <= firstGenPeakWave then
				currentAmount = currentAmount + 1
			else
				currentAmount = currentAmount - 3
			end
			if i == waveNumber then
				break
			end
		end
		return math.max(0, currentAmount)
	end
}
registry.enemies.bomber2 = {
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
		local currentAmount = 0
		for i = 1, waveNumber do
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
}
registry.enemies.bomber3 = {
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
		local currentAmount = 0
		for i = 1, waveNumber do
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
}

return registry
