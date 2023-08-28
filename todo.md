# Before release

- Finish score recording system (prompt player to enter name on first quit attempt and on game over and on victory, warn on score failure to be recorded)
- Handle without crashing and warn about invalid score records
- Balance score so that no factor dominates

- Add animated sprites to enemy bullets
- Sound effects for: shots from all enemy classes, player shots, player explosion, game over, boss start, game completed, powerup acquired, hyper beam firing, extra life(s) acquried

- Add a boss that constructs itself over time with an animation, with velocity boosted implosions
- Boss "wave" as wave 20. After beating a stage of the boss you have to chase it while other enemies spawn and attack you, and the boss spawns nuisance fighters too.
- Ending where the player goes forwards and (relative to camera, so camera pos changes) moves to a point in the upper middle of the screen and then flies off as the camera stops(?). Don't forget to record score.

# Some other time

- Add difficulty scaling
- Add clickable linktree link to author in credits
- Wait for player to reach top of screen to go to results screen instead of a timer (maybe repurpose the timer to start when the player reaches the top of the screen)
- Add hacking with blue line effects around hackee, stopping them from shooting
- Make font cooler
- Use interpolation for respawn centring
- Add transitions to the particle background when in or out of a title screen submenu
- Ensure rainbow beam parts always connect
- Maybe make bombers static or circle-moving enemies whose offscreen radius is higher? Or maybe maybe them come in diagonally with an airstrike
- Check if MOVING off screen when off screen before deleting an enemy/enemyBullet
