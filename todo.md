# Before release

- Finish score recording system (prompt player to enter name on first quit attempt and on game over and on victory, warn on score failure to be recorded)
- Handle without crashing and warn about invalid score records
- Balance score so that no factor dominates

- Add animated sprites to enemy bullets
- Sound effects for: shots from all enemy classes, player shots, game over, boss start, game completed, powerup acquired, hyper beam firing, extra life(s) acquried

- Add bosses that construct themselves over time with an animation, with velocity boosted implosions
- Boss waves start at wave 15.
- Boss 1, wave 15: Ship made from two ships, shield goes from left side to right side, you hit the vulnerable side and when you've blown up either side you win.
- Boss 2, wave 16: Two ships, ship 1 moves slowly and ship 2 moves erratically, ship 1 has a shield which is fed by ship 2, and shoots balls of energy at you. Every time you hit the energy ball it moves the ball's velocity closer to the velocity that would hit ship 2 (so aim prediction). If you can get a large volley in fast enough the ball should be able to hit ship 2. When ship 2 is downed, ship 1 loses its shield and switches to *only* shooting touhou-style volleys at you.
- Boss 3, wave 17: Large flagship. So large that you fly above its hull and are blowing up towers and stuff. Shields appear that block your progress unless you shoot all the towers (with turrets) that support them. Eventually you reach a valley in the ship's surface and are faced with large amounts of minelayer enemies that block your progress, and have to fly through the valley to release your payload (nuclear bomb) into the reactor ventilation shaft. Adjust story accordingly.
- Ending where the player goes forwards and (relative to camera, so camera pos changes) moves to a point in the upper middle of the screen and then flies off as the camera stops(?). Don't forget to record score.
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
