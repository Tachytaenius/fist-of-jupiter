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
	contactDamage = 2,
	materialisationTime = 0.2
}
registry.enemies.bomber1 = {
	radius = 10,
	health = 2,
	colour = {0.6, 0.5, 0.6},
	speed = 50,
	shootTimerLength = 2,
	bulletSpeed = 250,
	bulletRadius = 2,
	bulletDamage = 2,
	contactDamage = 3,
	materialisationTime = 0.3
}

return registry
