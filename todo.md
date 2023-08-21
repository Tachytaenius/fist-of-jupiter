# Before release

- Add a recorded high score system with names that also records the version of the game. Allow starting on arbitrary waves. show wave start and end. replace 1 with "START", replace finalNonBossWave+1 with "BOSS". and replace end with "END" if the game was beaten. star for victory at boss, skull for death, door for quit, door and star for quitting between waves? Default to showing scores starting on 1 but allow changing category to other start waves. Save timestamp for scores in file. Show total number of scores saved in scores menu. add button to prune all but top 10 scores for all starting waves, add button to delete all scores
- Finish score recording system (prompt player to enter name on first quit attempt and on game over and on victory, warn on score failure to be recorded, add total length of time spent not waiting or in results screen)
- Add quitting to title from pause (use score recording code from love.quit)
- Balance score so that no factor dominates

- Add animated sprites to enemy bullets
- Sound effects for: game start, shots from all enemy classes, player shots, player explosion, game over, enemy explosion, boss start, game completed, powerup acquired, hyper beam firing, extra life acquried
- Add controls to title screen
- Add extra life source, maybe reduce starting extra lives

- Maybe make bombers static or circle-moving enemies whose offscreen radius is higher? Or maybe maybe them come in diagonally with an airstrike
- Check if MOVING off screen when off screen before deleting an enemy/enemyBullet

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
