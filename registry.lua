local registry = {}

registry.enemies = {}
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
	defeatScore = 50,
	materialisationTime = 0.2,
	count = function(waveNumber)
		local currentAmount = 5
		for i = 1, waveNumber do
			if i == waveNumber then
				break
			end
			if i <= 3 then
				currentAmount = currentAmount + 2
			else
				currentAmount = currentAmount - 4
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
	shootTimerLength = 0.75,
	bulletSpeed = 225,
	bulletRadius = 1.5,
	bulletDamage = 0.5,
	bulletCount = 4,
	bulletSpreadAngle = math.tau / 180,
	contactDamage = 4,
	accel = 225,
	defeatScore = 75,
	materialisationTime = 0.15,
	count = function(waveNumber)
		local currentAmount = 0
		for i = 1, waveNumber do
			if i == waveNumber then
				break
			end
			if i > 3 and i <= 6 then
				currentAmount = currentAmount + 4
			elseif i > 6 then
				currentAmount = currentAmount - 8
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
	defeatScore = 50,
	materialisationTime = 0.3,
	count = function(waveNumber)
		local currentAmount = 3
		for i = 1, waveNumber do
			if i == waveNumber then
				break
			end
			if i <= 3 then
				currentAmount = currentAmount + 1
			else
				currentAmount = currentAmount - 3
			end
		end
		return math.max(0, currentAmount)
	end
}
registry.enemies.bomber2 = {
	radius = 12,
	health = 4,
	colour = {0.6, 0.5, 0.6},
	speed = 75,
	shootTimerLength = 1.5,
	bulletSpeed = 175,
	bulletRadius = 3,
	bulletDamage = 3,
	bulletCount = 1,
	bulletSpreadAngle = 0,
	contactDamage = 6,
	accel = 175,
	defeatScore = 100,
	materialisationTime = 0.2,
	count = function(waveNumber)
		local currentAmount = 0
		for i = 1, waveNumber do
			if i == waveNumber then
				break
			end
			if i > 3 and i <= 6 then
				currentAmount = currentAmount + 3
			elseif i > 6 then
				currentAmount = currentAmount - 6
			end
		end
		return math.max(0, currentAmount)
	end
}

return registry
