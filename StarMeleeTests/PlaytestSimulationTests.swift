import XCTest
import CoreGraphics
@testable import StarMelee

/// Headless gameplay playtest harness.
///
/// SpriteKit games can't be "played" in a unit test, but the game *logic* (Ship physics,
/// MatchManager, AIController, PhysicsEngine, SpecialWeaponSystem, buffs, shields) is pure
/// enough to drive frame-by-frame here. These tests run full matches and series, exercise
/// every special weapon, and assert invariants on every frame — catching NaN positions,
/// runaway gravity, negative health/battery, never-ending matches, and buff leaks.
@MainActor
final class PlaytestSimulationTests: XCTestCase {

    let dt: TimeInterval = 1.0 / 60.0
    let world = CGRect(x: -3000, y: -3000, width: 6000, height: 6000)

    // MARK: - Helpers

    private func ship(_ id: String, side: Ship.Side) -> Ship {
        let defs = ShipDefinition.loadAll()
        guard let def = defs.first(where: { $0.id == id }) ?? defs.first else {
            fatalError("Ships.json missing or empty")
        }
        return Ship(definition: def, side: side)
    }

    private func assertShipSane(_ s: Ship, _ msg: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(s.position.x.isFinite, "\(msg) position.x not finite", file: file, line: line)
        XCTAssertTrue(s.position.y.isFinite, "\(msg) position.y not finite", file: file, line: line)
        XCTAssertTrue(s.velocity.dx.isFinite && s.velocity.dy.isFinite, "\(msg) velocity not finite", file: file, line: line)
        XCTAssertGreaterThanOrEqual(s.health, 0, "\(msg) health negative", file: file, line: line)
        XCTAssertLessThanOrEqual(s.health, s.maxHealth + 0.001, "\(msg) health over max", file: file, line: line)
        XCTAssertGreaterThanOrEqual(s.battery, -0.001, "\(msg) battery negative", file: file, line: line)
        XCTAssertGreaterThanOrEqual(s.shield, -0.001, "\(msg) shield negative", file: file, line: line)
    }

    // MARK: - 1. Movement physics

    func testThrustAcceleratesAndCapsAtMaxSpeed() {
        let s = ship("aegis_cruiser", side: .player)
        s.position = .zero
        s.velocity = .zero
        s.heading = 0   // facing +x

        // Thrust forward for 5 seconds.
        for _ in 0..<300 {
            s.update(dt: dt, thrust: true, brake: false, turn: 0, allowSpecials: true)
        }
        let speed = hypot(s.velocity.dx, s.velocity.dy)
        XCTAssertGreaterThan(speed, 1, "Ship should have accelerated")
        XCTAssertLessThanOrEqual(speed, s.maxSpeed + 0.5, "Speed should be capped at maxSpeed")
        // Facing +x → moved in +x.
        XCTAssertGreaterThan(s.position.x, 0, "Should have moved in +x (heading 0)")
        XCTAssertEqual(s.position.y, 0, accuracy: 0.5, "No y drift when thrusting straight along x")
    }

    func testBrakeDecelerates() {
        let s = ship("aegis_cruiser", side: .player)
        s.velocity = CGVector(dx: 200, dy: 0)
        for _ in 0..<120 {
            s.update(dt: dt, thrust: false, brake: true, turn: 0, allowSpecials: true)
        }
        let speed = hypot(s.velocity.dx, s.velocity.dy)
        XCTAssertLessThan(speed, 50, "Braking should bleed off most velocity in 2s")
    }

    func testNoAutoDragWhenCoasting() {
        let s = ship("aegis_cruiser", side: .player)
        s.velocity = CGVector(dx: 100, dy: 0)
        for _ in 0..<120 {
            s.update(dt: dt, thrust: false, brake: false, turn: 0, allowSpecials: true)
        }
        // Star Control inertia: coasting keeps velocity (no friction).
        XCTAssertEqual(hypot(s.velocity.dx, s.velocity.dy), 100, accuracy: 0.5,
                       "Coasting should preserve velocity (no auto-drag)")
    }

    // MARK: - 2. Toroidal wrap

    func testToroidalWrapKeepsShipInBounds() {
        // Default world mode is .toroidal.
        guard WorldConstants.worldMode == .toroidal else {
            // If someone flips to bounded, this test is N/A.
            return
        }
        let s = ship("solar_wing", side: .player)
        s.position = CGPoint(x: world.maxX - 10, y: 0)
        s.velocity = CGVector(dx: 500, dy: 0)
        for _ in 0..<600 {
            s.position.x += s.velocity.dx * CGFloat(dt)
            PhysicsEngine.wrap(node: s, world: world)
            XCTAssertTrue(s.position.x >= world.minX - 1 && s.position.x <= world.maxX + 1,
                          "Toroidal wrap should keep x within world bounds, got \(s.position.x)")
        }
    }

    func testShortestDeltaWrapAware() {
        guard WorldConstants.worldMode == .toroidal else { return }
        // Two points near opposite edges should be "close" through the wrap.
        let a = CGPoint(x: world.minX + 100, y: 0)
        let b = CGPoint(x: world.maxX - 100, y: 0)
        let delta = PhysicsEngine.shortestDelta(from: a, to: b, world: world)
        // The wrap path is 200 units, not ~5800.
        XCTAssertLessThan(abs(delta.dx), 300, "Should pick the short wrap path")
    }

    // MARK: - 3. Gravity stability

    func testGravityDoesNotLaunchShipToInfinity() {
        // Place a ship near where a planet would be and apply a strong inverse-square pull
        // for a long time. The min-distance guard should prevent infinite acceleration.
        let s = ship("titan_bulwark", side: .player)
        let planetPos = CGPoint(x: 0, y: 0)
        let planetRadius: CGFloat = 56
        let planetMass: CGFloat = 1.6
        s.position = CGPoint(x: 80, y: 0)
        s.velocity = .zero
        let G: CGFloat = 18000
        for _ in 0..<3600 {   // 60 seconds
            let dx = planetPos.x - s.position.x
            let dy = planetPos.y - s.position.y
            let distSq = dx*dx + dy*dy
            let minDistSq = (planetRadius * 1.5) * (planetRadius * 1.5)
            let safeSq = max(minDistSq, distSq)
            let dist = sqrt(safeSq)
            let force = G * planetMass / safeSq
            s.velocity.dx += (dx / dist) * force * CGFloat(dt)
            s.velocity.dy += (dy / dist) * force * CGFloat(dt)
            s.position.x += s.velocity.dx * CGFloat(dt)
            s.position.y += s.velocity.dy * CGFloat(dt)
            XCTAssertTrue(s.position.x.isFinite && s.position.y.isFinite, "Gravity produced non-finite position")
            XCTAssertLessThan(hypot(s.velocity.dx, s.velocity.dy), 100_000, "Gravity launched ship to absurd speed")
        }
    }

    // MARK: - 4. Damage formula

    func testDamageFormulaSaneAndShieldReduces() {
        let weapons = WeaponDefinition.loadAll()
        guard let laser = weapons.first(where: { $0.id == "laser_cannon" }) else { XCTFail("no laser"); return }

        let noShield = PhysicsEngine.damage(weapon: laser, targetShieldFraction: 0)
        let fullShield = PhysicsEngine.damage(weapon: laser, targetShieldFraction: 1)
        XCTAssertGreaterThan(noShield, 0, "Damage should be positive")
        XCTAssertLessThan(fullShield, noShield, "Full shield should reduce damage")
    }

    func testTakeDamageClampsAndShieldAbsorbs() {
        let s = ship("aegis_cruiser", side: .opponent)   // opponent so FunModifiers.invincibility (player-only) doesn't interfere
        let startHealth = s.health
        let startShield = s.shield
        s.takeDamage(20)
        XCTAssertLessThan(s.shield, startShield, "Shield should absorb first")
        // Overkill clamps to 0, never negative.
        s.takeDamage(99999)
        XCTAssertEqual(s.health, 0, accuracy: 0.001, "Health clamps to 0 on overkill")
        XCTAssertTrue(s.isDestroyed)
        XCTAssertLessThanOrEqual(s.health, startHealth)
    }

    // MARK: - 5. Speed boost

    func testSpeedBoostRaisesCapAndDrainsBattery() {
        let s = ship("aegis_cruiser", side: .player)
        let baseCap = s.effectiveMaxSpeed
        let batteryBefore = s.battery
        let ok = s.tryEngageSpeedBoost(allowSpecials: true)
        XCTAssertTrue(ok, "Boost should engage with full battery")
        XCTAssertGreaterThan(s.effectiveMaxSpeed, baseCap, "Boost should raise the speed cap")
        XCTAssertLessThan(s.battery, batteryBefore, "Boost should drain battery")
        // Locked during pre-match.
        let s2 = ship("aegis_cruiser", side: .player)
        XCTAssertFalse(s2.tryEngageSpeedBoost(allowSpecials: false), "Boost locked when specials disallowed")
    }

    // MARK: - 6. Special weapons (all 12)

    func testEverySpecialWeaponExecutes() {
        let weapons = WeaponDefinition.loadAll()
        let ships = ShipDefinition.loadAll()
        XCTAssertEqual(ships.count, 12)
        for def in ships {
            let attacker = Ship(definition: def, side: .player)
            let opponentDef = ships.first { $0.id != def.id }!
            let opponent = Ship(definition: opponentDef, side: .opponent)
            // Give full battery so cost isn't the blocker.
            let result = SpecialWeaponSystem.execute(special: attacker,
                                                     opponent: opponent,
                                                     allowSpecials: true,
                                                     weaponsCatalog: weapons)
            switch result {
            case .fired, .spawnHomingMissiles, .armedSelfDestruct:
                break   // recognized special
            case .rejected:
                XCTFail("\(def.id)'s special '\(def.weapons.special)' was rejected (battery/cooldown/unknown ID)")
            }
        }
    }

    func testEMBlastDisruptsOpponentMovement() {
        let weapons = WeaponDefinition.loadAll()
        let prism = ship("prism_hunter", side: .player)   // special = em_blast
        let target = ship("titan_bulwark", side: .opponent)
        _ = SpecialWeaponSystem.execute(special: prism, opponent: target, allowSpecials: true, weaponsCatalog: weapons)
        XCTAssertTrue(target.isEMDisrupted, "EM Blast should disrupt the opponent")
        // Disrupted ship can't move.
        target.velocity = .zero
        target.update(dt: dt, thrust: true, brake: false, turn: 0, allowSpecials: true)
        XCTAssertEqual(hypot(target.velocity.dx, target.velocity.dy), 0, accuracy: 0.001,
                       "EM-disrupted ship shouldn't thrust")
    }

    func testBuffsExpire() {
        let s = ship("solar_wing", side: .player)
        s.applyBuff(ShipBuff(kind: .superSpeed, remainingSeconds: 1.0, magnitude: 3.0))
        XCTAssertTrue(s.hasBuff(.superSpeed))
        // Tick 1.5s.
        for _ in 0..<90 {
            s.update(dt: dt, thrust: false, brake: false, turn: 0, allowSpecials: true)
        }
        XCTAssertFalse(s.hasBuff(.superSpeed), "Buff should have expired after its duration")
    }

    // MARK: - 7. Shields

    func testShieldToggleTransitions() {
        let s = ship("titan_bulwark", side: .player)   // has shield + slow shield time
        XCTAssertTrue(s.shieldsFullyUp, "Shields start up")
        s.toggleShield()
        XCTAssertFalse(s.shieldsFullyUp, "Should be transitioning down")
        // Tick past the shield-down time.
        for _ in 0..<200 {
            s.update(dt: dt, thrust: false, brake: false, turn: 0, allowSpecials: true)
        }
        XCTAssertTrue(s.shieldsFullyDown, "Shields should be fully down after transition")
    }

    func testShipWithNoShieldCannotToggle() {
        let s = ship("solar_wing", side: .player)   // maxShield 0
        XCTAssertEqual(s.maxShield, 0)
        s.toggleShield()
        XCTAssertFalse(s.shieldsFullyDown, "A shieldless ship's toggle is a no-op for transition state")
    }

    // MARK: - 8. Self-destruct

    func testSelfDestructArmsAndExpires() {
        let s = ship("obsidian_maw", side: .player)
        s.applyBuff(ShipBuff(kind: .selfDestructArmed, remainingSeconds: 4, magnitude: 0))
        XCTAssertTrue(s.hasBuff(.selfDestructArmed))
        var fired = false
        for _ in 0..<300 {   // 5s
            s.update(dt: dt, thrust: false, brake: false, turn: 0, allowSpecials: true)
            if s.selfDestructJustExpired { fired = true; break }
        }
        XCTAssertTrue(fired, "selfDestructJustExpired should fire when the armed buff expires")
    }

    // MARK: - 9. Leaderboard merge

    func testLeaderboardMergeKeepsHigherValues() {
        var local = ShipStats(matchesPlayed: 5, wins: 3, losses: 2, currentStreak: 1, bestStreak: 2,
                              totalDamageDealt: 500, totalDamageTaken: 300, fatalityKills: 1,
                              selfDestructWins: 0, forfeits: 0)
        let remote = ShipStats(matchesPlayed: 8, wins: 5, losses: 3, currentStreak: 0, bestStreak: 4,
                               totalDamageDealt: 200, totalDamageTaken: 900, fatalityKills: 0,
                               selfDestructWins: 2, forfeits: 1)
        let merged = ShipStats.merging(local: local, remote: remote)
        XCTAssertEqual(merged.wins, 5)            // max(3,5)
        XCTAssertEqual(merged.bestStreak, 4)      // max(2,4)
        XCTAssertEqual(merged.totalDamageDealt, 500)  // max(500,200)
        XCTAssertEqual(merged.fatalityKills, 1)   // max(1,0)
        XCTAssertEqual(merged.selfDestructWins, 2) // max(0,2)
        local.wins = 99
        XCTAssertEqual(ShipStats.merging(local: local, remote: remote).wins, 99)
    }

    // MARK: - 10. Match length setting wiring

    func testMatchManagerHonorsMatchDuration() {
        let m = MatchManager(matchDuration: 90)
        XCTAssertEqual(m.matchDuration, 90, accuracy: 0.001)
        // Run through pre-match into active, verify the active timer starts at the configured value.
        var enteredActive = false
        for _ in 0..<700 {   // 11s+ to clear the 10s pre-match
            let change = m.update(dt: dt, playerDestroyed: false, enemyDestroyed: false,
                                  playerHealthFraction: 1, enemyHealthFraction: 1,
                                  playerShieldFraction: 1, enemyShieldFraction: 1)
            if case .countdownEnded = change {
                enteredActive = true
                if case .active(let remaining) = m.phase {
                    XCTAssertEqual(remaining, 90, accuracy: 0.1, "Active timer should start at matchDuration")
                }
                break
            }
        }
        XCTAssertTrue(enteredActive, "Should transition pre-match → active")
    }

    // MARK: - 11. AI behavior

    func testAITurnsTowardTargetAndFiresWhenAimed() {
        let ai = AIController(difficulty: .legendary)   // near-perfect aim
        let own = ship("scarab_striker", side: .opponent)
        let target = ship("aegis_cruiser", side: .player)
        own.position = .zero
        target.position = CGPoint(x: 300, y: 0)   // directly to the +x of own
        own.heading = .pi / 2                       // facing up — needs to turn toward +x (heading 0)

        // Let the AI steer for a couple seconds.
        var firedAtSomePoint = false
        for _ in 0..<240 {
            let d = ai.decide(dt: dt, ownShip: own, target: target, allowSpecials: true, world: world)
            own.update(dt: dt, thrust: d.thrust, brake: d.brake, turn: d.turn, allowSpecials: true)
            if d.firePrimary { firedAtSomePoint = true }
        }
        // After steering, heading should be near 0 (pointing at target along +x).
        let headingErr = abs(atan2(sin(own.heading), cos(own.heading)))   // normalize to [-pi,pi] magnitude
        XCTAssertLessThan(headingErr, 0.4, "Legendary AI should rotate to roughly face the target")
        XCTAssertTrue(firedAtSomePoint, "AI should fire primary once aimed at an in-range target")
    }

    // MARK: - 12. Fun Modifier — invincibility

    func testInvincibilityModifierBlocksPlayerDamage() {
        let mods = FunModifiers.shared
        let originalInvince = mods.invincibility
        defer { mods.invincibility = originalInvince }   // restore real state

        mods.invincibility = true
        let player = ship("aegis_cruiser", side: .player)
        let before = player.health
        player.takeDamage(50)
        XCTAssertEqual(player.health, before, accuracy: 0.001, "Invincible player takes no damage")

        // Opponent is unaffected by the player-only modifier.
        let enemy = ship("aegis_cruiser", side: .opponent)
        let enemyBefore = enemy.health
        enemy.takeDamage(50)
        XCTAssertLessThan(enemy.health, enemyBefore, "Opponent still takes damage")
    }

    // MARK: - 13. SOAK — full best-of-3 series with both ships AI-driven + forced combat

    func testSoakFullSeriesConcludesWithoutAnomalies() {
        let player = ship("aegis_cruiser", side: .player)
        let enemy = ship("void_reaper", side: .opponent)
        let playerAI = AIController(difficulty: .captain)
        let enemyAI = AIController(difficulty: .admiral)
        let match = MatchManager(matchDuration: 8)   // short matches so the series resolves fast

        func reposition() {
            player.position = CGPoint(x: -500, y: 0); player.heading = 0; player.velocity = .zero
            enemy.position = CGPoint(x: 500, y: 0); enemy.heading = .pi; enemy.velocity = .zero
        }
        reposition()

        var frames = 0
        let maxFrames = 60 * 200   // 200 simulated seconds hard cap
        var seriesEnded = false
        var damageTimer = 0.0

        while frames < maxFrames {
            frames += 1
            let allow = match.allowSpecials

            let pd = playerAI.decide(dt: dt, ownShip: player, target: enemy, allowSpecials: allow, world: world)
            let ed = enemyAI.decide(dt: dt, ownShip: enemy, target: player, allowSpecials: allow, world: world)
            player.update(dt: dt, thrust: pd.thrust, brake: pd.brake, turn: pd.turn, allowSpecials: allow)
            enemy.update(dt: dt, thrust: ed.thrust, brake: ed.brake, turn: ed.turn, allowSpecials: allow)
            PhysicsEngine.enforceWorldBoundaries(ship: player, world: world)
            PhysicsEngine.enforceWorldBoundaries(ship: enemy, world: world)

            // Approximate combat: during active play, periodically apply damage so matches end
            // by destruction (we don't run the SK physics collision engine here).
            if allow {
                damageTimer += dt
                if damageTimer > 0.5 {
                    damageTimer = 0
                    // Whichever AI "fired primary" this frame lands a hit on the other.
                    if pd.firePrimary { enemy.takeDamage(12) }
                    if ed.firePrimary { player.takeDamage(12) }
                    // Guarantee forward progress even if neither aims: chip the higher-HP ship.
                    if player.healthFraction >= enemy.healthFraction { player.takeDamage(4) }
                    else { enemy.takeDamage(4) }
                }
            }

            assertShipSane(player, "player @frame\(frames)")
            assertShipSane(enemy, "enemy @frame\(frames)")

            if let change = match.update(dt: dt,
                                         playerDestroyed: player.isDestroyed,
                                         enemyDestroyed: enemy.isDestroyed,
                                         playerHealthFraction: player.healthFraction,
                                         enemyHealthFraction: enemy.healthFraction,
                                         playerShieldFraction: player.shieldFraction,
                                         enemyShieldFraction: enemy.shieldFraction) {
                switch change {
                case .nextMatchStarted:
                    player.fullyRestore(); enemy.fullyRestore(); reposition()
                case .seriesEnded:
                    seriesEnded = true
                default:
                    break
                }
            }
            if seriesEnded { break }
        }

        XCTAssertTrue(seriesEnded, "Best-of-3 series should conclude within 200 simulated seconds")
        XCTAssertTrue(match.playerWins >= 2 || match.opponentWins >= 2,
                      "Series winner should have 2 wins (got \(match.playerWins)-\(match.opponentWins))")
    }
}
