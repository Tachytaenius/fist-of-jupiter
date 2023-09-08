# Before release

- Finish score recording system (prompt player to enter name on first quit attempt and on game over and on victory, warn on score failure to be recorded)
- Handle without crashing and warn about invalid score records
- Balance score so that no factor dominates

- Add animated sprites to enemy bullets
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

- Boss waves start at wave 15.
- Boss 2, wave 16: Two ships, ship 1 moves slowly and ship 2 moves erratically, ship 1 has a shield which is fed by ship 2, and shoots balls of energy at you. Every time you hit the energy ball it moves the ball's velocity closer to the velocity that would hit ship 2 (so aim prediction). If you can get a large volley in fast enough the ball should be able to hit ship 2. When ship 2 is downed, ship 1 loses its shield and switches to *only* shooting touhou-style volleys at you.
- Boss 3, wave 17: Large flagship. Show player moving towards flagship, super metroid cutscene style. So large that you fly above its hull and are blowing up towers and stuff. Shields appear that block your progress unless you shoot all the towers (with turrets) that support them. Large amounts of minelayer enemies that block your progress. Your goal is to enter the reactor ventilation shaft and access the reactor to blow it up. Adjust story accordingly. An ally flies in with you as you race for the reactor through the ventilation shaft, and is shortly blown up by a dangerous ship, which chases you through the ventilation shaft. eventually you get to the reactor and the enemy hits something and tumbles into the reactor, taking away of its health bar (which appears beforehand?). You then fight spawned enemies (no score) and the reactor's turrets as you try to shoot into the reactor itself. when successful, large explosions and you fly out. Why couldn't you just fly straight for the shaft? Because there is a shield around the flagship, you had to go through a hole in it. Why couldn't you just go thru the hole and fly above the towers?  becuase the shield is very low to the ship's surface.
- super metroid explosion style ending where you fly away from the exploding flagship. Don't forget to record score.
- Fix finalNonBossWave + 1 being used as final wave, causing runs to be classified as victories when they weren't
- Possibly have Jovian command giving you information. When powerups are available, or what to do with the boss.

# Some other time

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
