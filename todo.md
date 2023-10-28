# Before release

- Finish score recording system (prompt player to enter name on first quit attempt and on game over and on victory, warn on score failure to be recorded (there's a TODO for it in the code), maybe alert that scores won't be recorded on an unknown version?)
- Balance score so that no factor dominates

- Add animated sprites to enemy bullets
- Add volume slider
- Sound effects for:
	- shots from all enemy classes
	- game over
	- boss start
	- game completed
	- powerup acquired
	- hyper beam firing
	- extra life(s) acquried
	- player hit received
	- enemy materialising
	- player materialising

- Boss 3, wave 17: Large flagship.
	Flagship is so large that you fly above its hull and are blowing up towers and stuff.
	Shields appear that block your progress unless you shoot all the towers (with turrets) that support them.
	Large amounts of minelayer enemies try to block your progress, being added to the pool as you pass by the shields walls.
	Your goal is to enter the reactor ventilation shaft and access the reactor to blow it up with your nuclear bomb payload-- adjust story accordingly.
	Why couldn't you just fly straight for the shaft? Because there is a shield around the flagship, you had to go through a hole in it.
	Why couldn't you just go thru the hole and fly above the towers?  becuase the shield is very low to the ship's surface.
- super metroid explosion style ending where you fly away from the exploding flagship. Don't forget to record score.

# Some other time

- Handle without crashing and warn about invalid score records
- Add different window sizes and fullscreen
- Add difficulty scaling
- Add clickable linktree link to author in credits
- Add hacking with blue line effects around hackee, stopping them from shooting
- Make font cooler
- Use interpolation for respawn centring
- Add transitions to the particle background when in or out of a title screen submenu
- Ensure rainbow beam parts always connect
- Maybe make bombers static or circle-moving enemies whose offscreen radius is higher? Or maybe maybe them come in diagonally with an airstrike
- Check if MOVING off screen when off screen before deleting an enemy/enemyBullet
- Add stereo to sounnd effects
- Possibly have Jovian command giving you information. When powerups are available, or what to do with the boss.
- Fix greeble shadows intersecting with object shadows wrong. see comments at top of main
- Have bubbles appear from player when thrusters engaged if player has powerup.
