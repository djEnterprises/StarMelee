# POLISH_CHECKLIST.md — Starfighter

The "a stranger would assume a studio made this" acceptance test. Claude Code reports each item as
🟢 green / 🟡 yellow / 🔴 red at the end of the polish work. Be honest — a truthful yellow is more
useful than an optimistic green.

## Game feel — Phase 1 done 2026-05-30
- [x] Hit-stop fires on meaningful impacts, scaled to magnitude
- [x] Screen shake is trauma-based, capped, and never nauseating (and respects Reduce Motion)
- [~] Camera has idle life + recoil kick + punch-zoom on big events  *(punch-zoom done; idle drift + fire-recoil deferred)*
- [ ] No linear tweens anywhere — everything eases/springs/overshoots  *(deferred — gameplay-motion easing pass)*
- [x] Enemies flash on hit and react visibly to damage and death  *(pre-existing in Ship.takeDamage)*
- [ ] Controls feel responsive (input buffering / coyote time present)  *(deferred — changes input logic)*
- [x] All feel constants live in one tunable `GameFeel` file

## Visual / VFX — Phase 2 (particles) done 2026-05-30
- [x] Explosions are layered (flash + shockwave + debris + sparks), not single puffs  *(white spark shower + tinted glowing debris on top of the shockwave rings)*
- [x] Weapons have muzzle flash, glowing projectiles/trails, and impact sparks
- [~] Additive blending + bloom on energy/engines/explosions  *(all particles additive-blended for glow; true post-process bloom via SKEffectNode/SKShader deferred)*
- [ ] Multi-layer parallax background with nebula/depth  *(deferred — Phase 3 art direction)*
- [ ] Cohesive color grade (LUT/vignette) — everything looks shot through one lens  *(deferred — Phase 3)*
- [x] Threats and pickups stay high-contrast and readable through all the juice  *(additive glow tuned to stay legible)*

## Audio
- [ ] Adaptive/layered music that responds to intensity
- [ ] Repeated SFX are pitch-varied (no robotic machine-gun sameness)
- [ ] Impacts have real low-end weight
- [ ] Music ducks under big SFX (sidechain)
- [ ] Master limiter; consistent loudness; nothing clips
- [ ] Audio interruptions and the silent switch handled correctly

## Haptics
- [ ] `CHHapticEngine` with reset/restart handling
- [ ] Distinct patterns mapped to pickup / fire / hit / explosion / charge by intensity + sharpness
- [ ] Haptics scale to event magnitude and don't fatigue
- [ ] User toggle present; system haptic settings honored

## Strategic depth
- [ ] At least one real risk/reward system
- [ ] Loadout/upgrade choices have meaningful tradeoffs (not flat % bumps)
- [ ] 4+ enemy types with distinct, response-demanding behaviors
- [ ] At least one boss with telegraphed, learnable phases
- [ ] Resource management creates moment-to-moment decisions
- [ ] Combo/multiplier rewards skillful aggression
- [ ] Difficulty curve tuned; sits in the flow channel
- [ ] Meta-progression "one more run" hook exists

## Presentation & UX
- [ ] Animated title screen with a logo sting
- [ ] All scene/menu changes use transitions — zero instant cuts
- [ ] HUD is minimal, animated, and feels designed
- [ ] Onboarding teaches by doing, not text walls
- [ ] Death/victory moment lands (slow-mo + counting score tally)
- [ ] Pause, settings (audio sliders, haptics toggle, accessibility, difficulty), credits all present
- [ ] Game Center leaderboards + achievements wired up
- [ ] No frozen black frames during loads/transitions

## Performance & hardening
- [ ] Locked 60fps (120 on ProMotion) under max on-screen entities — proven in Instruments
- [ ] Object pooling real; no hot-path allocations
- [ ] Draw calls batched; memory flat; no leaks
- [ ] Background/foreground, interruptions, low-power mode, multiple devices/aspect ratios tested
- [ ] No debug overlays, console spam, or placeholder assets shipping

## Store readiness
- [ ] App icon, launch screen, and App Store screenshots at studio quality
- [ ] Metadata, naming, and versioning consistent
- [ ] Asset licenses/attribution tracked and clean

## The final gut check
- [ ] Every player action gets feedback within one frame (visual + audio + haptic where it fits)
- [ ] A stranger playing it could not tell it was built by a team of two
- [ ] It has a genuine "one more run" pull
